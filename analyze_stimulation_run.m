function analyze_stimulation_run(parent_folder, varargin)
% ANALYZE_STIMULATION_RUN
% Full pipeline for one experimental condition (e.g., 1Hz/30%duty).
%
% Expects parent_folder to contain 5 subfolders whose names contain _N
% near the end (where N is the index 0..4). Trailing extensions like
% .bin in folder names are tolerated.
%
% Outputs to <parent_folder>_analysis/:
%   timeseries.csv  - all numerical data per frame
%   timeseries.png  - stacked time-depth image with boundary lines

% -------- Parse options ------------------------------------------------
p = inputParser;
addParameter(p, 'PxPerMm', 200);
addParameter(p, 'AvgColumns', 1);
addParameter(p, 'SkipSegmented', true);
addParameter(p, 'CropFrac', 0.5);
addParameter(p, 'OutputDir', '');
addParameter(p, 'MirrorDir', '');
addParameter(p, 'FilePrefix', '');
parse(p, varargin{:});
opts = p.Results;
% -----------------------------------------------------------------------

if ~exist(parent_folder, 'dir')
    error('Parent folder not found: %s', parent_folder);
end
parent_clean = regexprep(parent_folder, '[\\/]+$', '');

% Primary legacy location: ALWAYS inside the protocol folder (<cdir>_analysis)
if ~isempty(opts.OutputDir)
    analysis_dir = opts.OutputDir;
else
    analysis_dir = [parent_clean, '_analysis'];
end
if ~exist(analysis_dir, 'dir'); mkdir(analysis_dir); end

% --- Find & order subfolders by _N (allowing trailing .ext) -----------
% IMPORTANT: ignore folders that end in _out (these are our own
% segmentation outputs from previous runs).
subs = dir(parent_folder);
subs = subs([subs.isdir] & ~ismember({subs.name}, {'.', '..'}));

% Filter out _out folders (our own outputs) before regex matching
keep_not_out = ~endsWith({subs.name}, '_out', 'IgnoreCase', true);
subs = subs(keep_not_out);

sub_idx = nan(numel(subs), 1);
for i = 1:numel(subs)
    tok = regexp(subs(i).name, '_(\d+)(?:\.[^.]+)?$', 'tokens', 'once');
    if ~isempty(tok); sub_idx(i) = str2double(tok{1}); end
end
keep = ~isnan(sub_idx);
subs = subs(keep);
sub_idx = sub_idx(keep);
[sub_idx, order] = sort(sub_idx);
subs = subs(order);

if isempty(subs)
    error('No subfolders matching pattern "_N" or "_N.ext" found in %s', parent_folder);
end

fprintf('Found %d subfolders:\n', numel(subs));
for i = 1:numel(subs)
    fprintf('  index %d : %s\n', sub_idx(i), subs(i).name);
end
fprintf('\n');

% --- Step 1: segment each subfolder ------------------------------------
seg_dirs = cell(numel(subs), 1);
for i = 1:numel(subs)
    sub_path = fullfile(parent_folder, subs(i).name);
    seg_path = [regexprep(sub_path, '[\\/]+$', ''), '_out'];
    seg_dirs{i} = seg_path;

    if opts.SkipSegmented && exist(seg_path, 'dir')
        existing = dir(fullfile(seg_path, '*_dp.mat'));
        n_imgs   = count_images(sub_path);
        if numel(existing) >= n_imgs && n_imgs > 0
            fprintf('[skip seg] %s already has %d _dp.mat files\n', ...
                subs(i).name, numel(existing));
            continue;
        end
    end

    fprintf('Segmenting %s ...\n', subs(i).name);
    segment_new_images(sub_path, seg_path);
    fprintf('\n');
end

% --- Step 2: gather frames in order ------------------------------------
all_frames = struct('mat_path', {}, 'sub_idx', {}, 'frame_idx', {}, 'name', {});
for i = 1:numel(subs)
    mats = dir(fullfile(seg_dirs{i}, '*_dp.mat'));
    if isempty(mats)
        warning('No _dp.mat in %s, skipping', seg_dirs{i});
        continue;
    end
    fnums = nan(numel(mats), 1);
    for k = 1:numel(mats)
        base = erase(mats(k).name, '_dp.mat');
        tok = regexp(base, '_(\d+)$', 'tokens', 'once');
        if ~isempty(tok); fnums(k) = str2double(tok{1}); end
    end
    [fnums, ord] = sort(fnums);
    mats = mats(ord);

    for k = 1:numel(mats)
        all_frames(end+1).mat_path = fullfile(seg_dirs{i}, mats(k).name); %#ok<AGROW>
        all_frames(end).sub_idx    = sub_idx(i);
        all_frames(end).frame_idx  = fnums(k);
        all_frames(end).name       = erase(mats(k).name, '_dp.mat');
    end
end

N = numel(all_frames);
if N == 0; error('No segmented frames found.'); end
fprintf('Total frames in time series: %d\n\n', N);

% --- Step 3: extract middle-column values per frame --------------------
top_sc = nan(N, 1);
bot_sc = nan(N, 1);
end_ed = nan(N, 1);
stacked_cols = [];

for f = 1:N
    S = load(all_frames(f).mat_path);
    W_orig = numel(S.top_sc);
    mid = round(W_orig / 2);
    span = max(0, floor((opts.AvgColumns - 1) / 2));
    c1 = max(1, mid - span);
    c2 = min(W_orig, mid + span);

    top_sc(f) = mean(S.top_sc(c1:c2));
    bot_sc(f) = mean(S.bot_sc(c1:c2));
    end_ed(f) = mean(S.end_ed(c1:c2));

    raw_path = find_raw_image(parent_folder, all_frames(f).name);
    if ~isempty(raw_path)
        try
            raw = imread(raw_path);
            if ndims(raw) == 3; raw = rgb2gray(raw); end
            col = mean(raw(:, c1:c2), 2);
            if isempty(stacked_cols)
                stacked_cols = zeros(size(raw,1), N, 'like', col);
            end
            stacked_cols(:, f) = col; %#ok<AGROW>
        catch
        end
    end
end

% --- Step 4: thickness time series in mm -------------------------------
% Filter frame-to-frame impulse noise/spikes on end_ed time series
try
    end_ed_clean = hampel(end_ed, 7, 2.5);
catch
    end_ed_clean = medfilt1(end_ed, 7);
end
end_ed = smoothdata(end_ed_clean, 'sgolay', 9);
end_ed = max(end_ed, bot_sc + 3);

px_per_mm = opts.PxPerMm;
sc_thick_mm     = (bot_sc - top_sc) / px_per_mm;
ed_thick_mm     = (end_ed - bot_sc) / px_per_mm;
total_thick_mm  = (end_ed - top_sc) / px_per_mm;
surface_disp_mm = (top_sc - top_sc(1)) / px_per_mm;

% --- Step 5a: write CSV ------------------------------------------------
% Legacy standard: directly saved inside the protocol's _analysis folder
csv_path = fullfile(analysis_dir, 'timeseries.csv');
T = table((1:N).', [all_frames.sub_idx].', [all_frames.frame_idx].', ...
    {all_frames.name}.', ...
    top_sc, bot_sc, end_ed, ...
    sc_thick_mm, ed_thick_mm, total_thick_mm, surface_disp_mm, ...
    'VariableNames', {'global_idx','sub_idx','frame_idx','name', ...
    'top_sc_px','bot_sc_px','end_ed_px', ...
    'sc_thickness_mm','ed_thickness_mm','total_thickness_mm','surface_disp_mm'});
writetable(T, csv_path);
fprintf('Saved CSV : %s\n', csv_path);

print_stats('SC thickness (mm)',   sc_thick_mm);
print_stats('ED thickness (mm)',   ed_thick_mm);
print_stats('Total thickness (mm)',total_thick_mm);
print_stats('Surface displacement (mm)', surface_disp_mm);

% --- Step 5b: save single-panel stacked PNG (cropped) ------------------
png_path = fullfile(analysis_dir, 'timeseries.png');
make_figure(stacked_cols, top_sc, bot_sc, end_ed, ...
    png_path, parent_clean, px_per_mm, opts.CropFrac);
fprintf('Saved figure: %s\n', png_path);

% --- Step 5c: Mirror to Subject level folder (Optional Dual-Save) ------
if ~isempty(opts.MirrorDir)
    try
        if ~exist(opts.MirrorDir, 'dir'); mkdir(opts.MirrorDir); end
        prefix_str = '';
        if ~isempty(opts.FilePrefix)
            prefix_str = [regexprep(opts.FilePrefix, '[\\/]+$', ''), '_'];
        end
        copyfile(csv_path, fullfile(opts.MirrorDir, [prefix_str, 'timeseries.csv']));
        copyfile(png_path, fullfile(opts.MirrorDir, [prefix_str, 'timeseries.png']));
        fprintf('Mirrored to Subject folder: %s\n', opts.MirrorDir);
    catch
    end
end

fprintf('\nDone.\n');
end

% =========================================================================
function n = count_images(folder)
exts = {'*.jpg','*.jpeg','*.png','*.bmp','*.tif','*.tiff'};
n = 0;
for k = 1:numel(exts); n = n + numel(dir(fullfile(folder, exts{k}))); end
end

% =========================================================================
function p = find_raw_image(parent_folder, base)
exts = {'.jpg','.jpeg','.png','.bmp','.tif','.tiff'};
subs = dir(parent_folder);
subs = subs([subs.isdir] & ~ismember({subs.name},{'.','..'}));
% Skip _out folders here too, otherwise we'd waste time looking in them
subs = subs(~endsWith({subs.name}, '_out', 'IgnoreCase', true));
for i = 1:numel(subs)
    for e = 1:numel(exts)
        candidate = fullfile(parent_folder, subs(i).name, [base, exts{e}]);
        if exist(candidate, 'file'); p = candidate; return; end
    end
end
p = '';
end

% =========================================================================
function print_stats(label, x)
fprintf('  %-26s mean=%.3f  std=%.3f  min=%.3f  max=%.3f  p2p=%.3f\n', ...
    label, mean(x), std(x), min(x), max(x), max(x)-min(x));
end

% =========================================================================
function make_figure(stack, top_sc, bot_sc, end_ed, out_path, ttl, px_per_mm, crop_frac)
N = numel(top_sc);
t = 1:N;

if isempty(stack)
    fprintf('  [warn] No raw images found, skipping figure.\n');
    return;
end

H = size(stack, 1);
H_keep = max(1, round(H * crop_frac));
stack_crop = stack(1:H_keep, :);

fig = figure('Visible','off','Position',[100 100 1600 600], 'Color','w');
imshow(stack_crop, []); hold on;
plot(t, top_sc, 'r-', 'LineWidth', 1.0);
plot(t, bot_sc, 'y-', 'LineWidth', 1.0);
plot(t, end_ed, 'g-', 'LineWidth', 1.0);
hold off;
title(sprintf('%s   N=%d frames   1mm = %d px', ttl, N, px_per_mm), ...
    'Interpreter','none');
xlabel('Frame index');
ylabel('Depth (px)');
legend({'top SC','bot SC','end ED'}, 'Location','eastoutside');

exportgraphics(fig, out_path, 'Resolution', 150);
close(fig);
end