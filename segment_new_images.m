function segment_new_images(input_folder, output_folder, model_path, save_overlays, batch_size)
% SEGMENT_NEW_IMAGES
% Run trained U-Net + DP boundary extraction on a folder of new OCT images.
% Optimized with Mini-Batching for GPU acceleration.

% -------- Config -------------------------------------------------------
trained_dir_dev = fullfile(fileparts(mfilename('fullpath')), 'trained_variantA');
dp_lambda   = 1.5;
dp_jump     = 4;
img_exts    = {'*.jpg', '*.jpeg', '*.png', '*.bmp', '*.tif', '*.tiff'};
% -----------------------------------------------------------------------

if nargin < 2 || isempty(output_folder)
    in_clean = regexprep(input_folder, '[\\/]+$', '');
    output_folder = [in_clean, '_out'];
end

if nargin < 3 || isempty(model_path)
    model_path = find_bundled_model(trained_dir_dev);
end

if nargin < 4 || isempty(save_overlays)
    save_overlays = false;
end

if nargin < 5 || isempty(batch_size)
    batch_size = 8; % Default batch size tuned for 4GB VRAM
end

if ~exist(output_folder, 'dir'); mkdir(output_folder); end

use_gpu = canUseGPU();

% --- Load model (cached across calls) ----------------------------------
persistent NET_CACHE CACHE_PATH
if isempty(NET_CACHE) || ~strcmp(CACHE_PATH, model_path)
    if use_gpu; try; gpuDevice(1); catch; end; end
    fprintf('Loading model: %s\n', model_path);
    NET_CACHE  = load(model_path);
    CACHE_PATH = model_path;
end
M   = NET_CACHE;
net = M.net;

if isfield(M, 'target_size') && ~isempty(M.target_size)
    target_size = M.target_size;
else
    target_size = [512, 1024];
end

nch = get_input_channels(net, 3);

if use_gpu
    fprintf('Using GPU with batch size %d.\n', batch_size);
else
    fprintf('No GPU available, running on CPU.\n');
end

img_files = [];
for k = 1:numel(img_exts)
    img_files = [img_files; dir(fullfile(input_folder, img_exts{k}))]; %#ok<AGROW>
end
keep = ~contains({img_files.name}, '_dp.', 'IgnoreCase', true) & ...
       ~contains({img_files.name}, '_overlay.', 'IgnoreCase', true) & ...
       ~contains({img_files.name}, '_mask.', 'IgnoreCase', true);
img_files = img_files(keep);

n = numel(img_files);
if n == 0; error('No images found in %s', input_folder); end
fprintf('Found %d images. Output -> %s\n\n', n, output_folder);

t_start = tic;
n_ok = 0;
n_fail = 0;

for i = 1:batch_size:n
    chunk_end = min(i + batch_size - 1, n);
    cur_batch_size = chunk_end - i + 1;
    
    X_batch = zeros(target_size(1), target_size(2), nch, cur_batch_size, 'single');
    batch_meta = cell(cur_batch_size, 1);
    
    % Prepare batch
    for b = 1:cur_batch_size
        idx = i + b - 1;
        name = img_files(idx).name;
        [~, base, ~] = fileparts(name);
        in_path  = fullfile(input_folder, name);
        
        try
            raw = imread(in_path);
            if ndims(raw) == 3
                raw_gray = rgb2gray(raw);
            else
                raw_gray = raw;
            end
            [H_orig, W_orig] = size(raw_gray);
            
            [I_proc, meta] = preprocess_image_only(raw);
            [H_proc, W_proc] = size(I_proc);
            
            I_for_net = uint8(round(I_proc * 255));
            I_for_net = imresize(I_for_net, target_size, 'bilinear');
            
            if nch == 3 && size(I_for_net, 3) == 1
                I_for_net = repmat(I_for_net, [1 1 3]);
            end
            
            X_batch(:,:,:,b) = single(I_for_net);
            
            batch_meta{b} = struct('base', base, 'raw_gray', raw_gray, 'H_orig', H_orig, ...
                'W_orig', W_orig, 'H_proc', H_proc, 'W_proc', W_proc, 'meta', meta, 'name', name);
        catch ME
            batch_meta{b} = struct('error', ME.message, 'name', name);
            n_fail = n_fail + 1;
            fprintf('  [FAIL PREP] %s : %s\n', name, ME.message);
        end
    end
    
    % Inference
    X = dlarray(X_batch, 'SSCB');
    if use_gpu; X = gpuArray(X); end
    Y = predict(net, X);
    prob_batch = double(extractdata(gather(Y))); % Shape: [H, W, Classes, BatchSize]
    
    % Process predictions
    for b = 1:cur_batch_size
        m = batch_meta{b};
        if isfield(m, 'error'); continue; end
        
        try
            prob = prob_batch(:,:,:,b);
            
            [top_n, bot_n, end_n] = extract_boundaries_dp(prob, dp_lambda, dp_jump);
            
            H_net = target_size(1); W_net = target_size(2);
            scale_row = m.H_proc / H_net;
            col_net  = 1:W_net;
            col_orig_query = linspace(1, W_net, m.W_orig);
            
            top_orig = interp1(col_net, top_n, col_orig_query, 'linear', 'extrap') * scale_row;
            bot_orig = interp1(col_net, bot_n, col_orig_query, 'linear', 'extrap') * scale_row;
            end_orig = interp1(col_net, end_n, col_orig_query, 'linear', 'extrap') * scale_row;
            
            top_orig = max(1, min(m.H_orig, top_orig));
            bot_orig = max(top_orig + 2, min(m.H_orig, bot_orig));
            end_orig = max(bot_orig + 5, min(m.H_orig, end_orig));
            
            thickness_sc = bot_orig - top_orig;
            thickness_ed = end_orig - bot_orig;
            
            out = struct();
            out.top_sc       = top_orig;
            out.bot_sc       = bot_orig;
            out.end_ed       = end_orig;
            out.thickness_sc = thickness_sc;
            out.thickness_ed = thickness_ed;
            out.image_size   = [m.H_orig, m.W_orig];
            out.preproc_meta = m.meta;
            out.model_path   = model_path;
            out.dp_params    = struct('lambda', dp_lambda, 'max_jump', dp_jump);
            
            out_mat  = fullfile(output_folder, [m.base, '_dp.mat']);
            save(out_mat, '-struct', 'out');
            
            if save_overlays
                out_png  = fullfile(output_folder, [m.base, '_dp.png']);
                save_overlay(m.raw_gray, top_orig, bot_orig, end_orig, out_png, m.base);
            end
            
            n_ok = n_ok + 1;
            idx = i + b - 1;
            if mod(idx, 25) == 0 || idx == n
                fprintf('  [%4d/%4d] %-25s  SC=%.1fpx  ED=%.1fpx  (%.1fs elapsed)\n', ...
                    idx, n, m.base, mean(thickness_sc), mean(thickness_ed), toc(t_start));
            end
            
        catch ME
            n_fail = n_fail + 1;
            fprintf('  [FAIL PROC] %s : %s\n', m.name, ME.message);
        end
    end
end

fprintf('\nDone. %d ok, %d failed in %.1f seconds (%.2f s/image).\n', ...
    n_ok, n_fail, toc(t_start), toc(t_start)/max(n_ok,1));
end

% =========================================================================
function c = get_input_channels(net, default_c)
c = default_c;
try
    L = net.Layers;
    for k = 1:numel(L)
        if isprop(L(k), 'InputSize') && numel(L(k).InputSize) >= 3
            c = L(k).InputSize(3);
            return;
        end
    end
catch
end
end

% =========================================================================
function model_path = find_bundled_model(dev_dir)
if isdeployed
    candidates = dir(fullfile(ctfroot, '**', 'unet_variantA_*.mat'));
else
    candidates = dir(fullfile(dev_dir, 'unet_variantA_*.mat'));
end
if isempty(candidates)
    if isdeployed
        error('Bundled model not found in compiled exe. Rebuild with -a flag pointing at unet_variantA_*.mat.');
    else
        error('No trained model (unet_variantA_*.mat) found in %s', dev_dir);
    end
end
[~, ix] = max([candidates.datenum]);
model_path = fullfile(candidates(ix).folder, candidates(ix).name);
end

% =========================================================================
function save_overlay(img, top_sc, bot_sc, end_ed, out_path, ttl)
fig = figure('Visible','off','Position',[100 100 1400 700]);
imshow(img, []); hold on;
W = numel(top_sc);
plot(1:W, top_sc, 'r-', 'LineWidth', 1.2);
plot(1:W, bot_sc, 'y-', 'LineWidth', 1.2);
plot(1:W, end_ed, 'g-', 'LineWidth', 1.2);
hold off;
title(sprintf('%s   SC=%.1fpx   ED=%.1fpx', ttl, ...
    mean(bot_sc - top_sc), mean(end_ed - bot_sc)), ...
    'Interpreter', 'none', 'Color', 'w');
set(gca, 'Color', 'k');
set(gcf, 'Color', 'k');
legend('top SC', 'bot SC', 'end ED', 'Location', 'southeast', 'TextColor', 'w');
exportgraphics(fig, out_path, 'Resolution', 100);
close(fig);
end