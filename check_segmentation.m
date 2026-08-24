function check_segmentation(input_folder, n_samples, grid_cols)
% CHECK_SEGMENTATION
% Quick visual QC: pick N random images from a folder, overlay the
% predicted DP boundaries, show all in one grid figure.
%
% Usage:
%   check_segmentation(input_folder)              % 9 random samples
%   check_segmentation(input_folder, 16)          % 16 random samples
%   check_segmentation(input_folder, 12, 4)       % 12 samples in 3x4 grid
%
% Inputs:
%   input_folder : path to a folder containing the original .jpg/.png images
%                  (script automatically looks for matching <name>_dp.mat
%                  files in <input_folder>_out)
%   n_samples    : number of random images to display (default 9)
%   grid_cols    : columns in the grid (default auto-computed)

if nargin < 2 || isempty(n_samples); n_samples = 9; end
if nargin < 3 || isempty(grid_cols)
    grid_cols = ceil(sqrt(n_samples));
end
grid_rows = ceil(n_samples / grid_cols);

% --- Locate output folder ---------------------------------------------
in_clean = regexprep(input_folder, '[\\/]+$', '');
out_folder = [in_clean, '_out'];
if ~exist(out_folder, 'dir')
    error('No segmentation folder found at: %s\nDid you run segment_new_images yet?', out_folder);
end

% --- Find images that have matching .mat ------------------------------
exts = {'*.jpg','*.jpeg','*.png','*.bmp','*.tif','*.tiff'};
img_files = [];
for k = 1:numel(exts)
    img_files = [img_files; dir(fullfile(input_folder, exts{k}))]; %#ok<AGROW>
end

paired = struct('img_path', {}, 'mat_path', {}, 'name', {});
for i = 1:numel(img_files)
    [~, base, ~] = fileparts(img_files(i).name);
    mat_path = fullfile(out_folder, [base, '_dp.mat']);
    if exist(mat_path, 'file')
        paired(end+1).img_path = fullfile(input_folder, img_files(i).name); %#ok<AGROW>
        paired(end).mat_path = mat_path;
        paired(end).name = base;
    end
end

if isempty(paired)
    error('No matching image+mat pairs found between %s and %s', input_folder, out_folder);
end

n_avail = numel(paired);
n = min(n_samples, n_avail);
fprintf('Found %d segmented images. Showing %d random samples.\n', n_avail, n);

% --- Pick random samples ----------------------------------------------
rng('shuffle');
sel = randperm(n_avail, n);
sel = sort(sel);   % display in order for easier reference

% --- Build grid figure -------------------------------------------------
fig = figure('Name', sprintf('QC - %s', input_folder), ...
    'Position', [50 50 1800 1000], 'Color', 'k');
tl = tiledlayout(fig, grid_rows, grid_cols, 'TileSpacing','tight','Padding','tight');
title(tl, sprintf('Segmentation QC: %s   (%d/%d shown)', input_folder, n, n_avail), ...
    'Interpreter','none', 'Color','w');

for i = 1:n
    p = paired(sel(i));
    raw = imread(p.img_path);
    if ndims(raw) == 3; raw = rgb2gray(raw); end
    S = load(p.mat_path);

    % Crop to top half for visibility (matches preprocessing)
    H = size(raw, 1);
    H_keep = round(H * 0.5);
    raw_crop = raw(1:H_keep, :);

    nexttile;
    imshow(raw_crop, []); hold on;
    W = numel(S.top_sc);
    plot(1:W, S.top_sc, 'r-', 'LineWidth', 1.0);
    plot(1:W, S.bot_sc, 'y-', 'LineWidth', 1.0);
    plot(1:W, S.end_ed, 'g-', 'LineWidth', 1.0);
    hold off;
    title(sprintf('%s  SC=%.1fpx ED=%.1fpx', p.name, ...
        mean(S.thickness_sc), mean(S.thickness_ed)), ...
        'Interpreter','none','Color','w','FontSize', 8);
end

% Legend on first tile only
ax = findall(fig, 'type', 'axes');
if ~isempty(ax)
    legend(ax(end), {'top SC','bot SC','end ED'}, ...
        'Location','southoutside','Orientation','horizontal','TextColor','w', 'FontSize', 7);
end

fprintf('Done. Examine the figure - look for:\n');
fprintf('  - Red/yellow lines hugging the bright surface band\n');
fprintf('  - Green line at the visible epidermis-dermis transition\n');
fprintf('  - No wild jumps or lines floating in noise\n');
end