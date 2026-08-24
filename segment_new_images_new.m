function segment_new_images(input_folder, output_folder, model_path, save_overlays)
% SEGMENT_NEW_IMAGES
% Run trained U-Net + DP boundary extraction on a folder of new OCT images.
%
% In MATLAB: looks for model in C:\OCT\Chosen Ones\preprocessed\use\segment\trained_v2
% In compiled .exe: looks for the bundled model (ctfroot)
%
% Usage:
%   segment_new_images(input_folder)
%   segment_new_images(input_folder, output_folder)
%   segment_new_images(input_folder, output_folder, model_path)
%   segment_new_images(input_folder, output_folder, model_path, save_overlays)

% -------- Config -------------------------------------------------------
trained_dir_dev = 'C:\OCT\Chosen Ones\preprocessed\use\segment\trained_v2';
dp_lambda   = 0.1;
dp_jump     = 5;
img_exts    = {'*.jpg', '*.jpeg', '*.png', '*.bmp', '*.tif', '*.tiff'};
% -----------------------------------------------------------------------

if nargin < 2 || isempty(output_folder)
    in_clean = regexprep(input_folder, '[\\/]+$', '');
    output_folder = [in_clean, '_out'];
    fprintf('Output folder auto-set to: %s\n', output_folder);
end

if nargin < 3 || isempty(model_path)
    model_path = find_bundled_model(trained_dir_dev);
end

if nargin < 4 || isempty(save_overlays)
    save_overlays = false;
end

if ~exist(output_folder, 'dir'); mkdir(output_folder); end

fprintf('Loading model: %s\n', model_path);
M = load(model_path);
net = M.net;
target_size = M.target_size;
use_gpu = canUseGPU();
if use_gpu
    try; gpuDevice(1); catch; end
    fprintf('Using GPU.\n');
else
    fprintf('No GPU available, running on CPU (slower).\n');
end
if save_overlays
    fprintf('Overlay PNGs: ON (slower)\n');
else
    fprintf('Overlay PNGs: OFF (fast - only .mat files saved)\n');
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

for i = 1:n
    name = img_files(i).name;
    [~, base, ~] = fileparts(name);
    in_path  = fullfile(input_folder, name);
    out_mat  = fullfile(output_folder, [base, '_dp.mat']);
    out_png  = fullfile(output_folder, [base, '_dp.png']);

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
        assert(W_proc == W_orig, 'Width changed during preprocessing.');

        I_for_net = uint8(round(I_proc * 255));
        I_for_net = imresize(I_for_net, target_size, 'bilinear');

        X = single(I_for_net);
        X = dlarray(X, 'SSCB');
        if use_gpu; X = gpuArray(X); end
        Y = predict(net, X);
        prob = double(extractdata(gather(Y)));

        [top_n, bot_n, end_n] = extract_boundaries_dp(prob, dp_lambda, dp_jump);

        H_net = target_size(1); W_net = target_size(2);
        scale_row = H_proc / H_net;
        col_net  = 1:W_net;
        col_orig_query = linspace(1, W_net, W_orig);

        top_orig = interp1(col_net, top_n, col_orig_query, 'linear', 'extrap') * scale_row;
        bot_orig = interp1(col_net, bot_n, col_orig_query, 'linear', 'extrap') * scale_row;
        end_orig = interp1(col_net, end_n, col_orig_query, 'linear', 'extrap') * scale_row;

        top_orig = max(1, min(H_orig, top_orig));
        bot_orig = max(top_orig, min(H_orig, bot_orig));
        end_orig = max(bot_orig, min(H_orig, end_orig));

        thickness_sc = bot_orig - top_orig;
        thickness_ed = end_orig - bot_orig;

        out = struct();
        out.top_sc       = top_orig;
        out.bot_sc       = bot_orig;
        out.end_ed       = end_orig;
        out.thickness_sc = thickness_sc;
        out.thickness_ed = thickness_ed;
        out.image_size   = [H_orig, W_orig];
        out.preproc_meta = meta;
        out.model_path   = model_path;
        out.dp_params    = struct('lambda', dp_lambda, 'max_jump', dp_jump);
        save(out_mat, '-struct', 'out');

        if save_overlays
            save_overlay(raw_gray, top_orig, bot_orig, end_orig, out_png, base);
        end

        n_ok = n_ok + 1;
        if mod(i, 25) == 0 || i == n
            fprintf('  [%4d/%4d] %-25s  SC=%.1fpx  ED=%.1fpx  (%.1fs elapsed)\n', ...
                i, n, base, mean(thickness_sc), mean(thickness_ed), toc(t_start));
        end

    catch ME
        n_fail = n_fail + 1;
        fprintf('  [FAIL] %s : %s\n', name, ME.message);
    end
end

fprintf('\nDone. %d ok, %d failed in %.1f seconds (%.2f s/image).\n', ...
    n_ok, n_fail, toc(t_start), toc(t_start)/max(n_ok,1));
end

% =========================================================================
function model_path = find_bundled_model(dev_dir)
% Find trained model. In compiled exe use ctfroot; in dev use dev_dir.
if isdeployed
    % Compiled: model is bundled inside the exe. ctfroot points to where
    % MCR extracts everything at runtime.
    candidates = dir(fullfile(ctfroot, '**', 'unet_v2_*.mat'));
else
    candidates = dir(fullfile(dev_dir, 'unet_v2_*.mat'));
end

if isempty(candidates)
    if isdeployed
        error('Bundled model not found in compiled exe. Rebuild with -a flag pointing at unet_v2_*.mat.');
    else
        error('No trained model found in %s', dev_dir);
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