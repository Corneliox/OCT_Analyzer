function evaluate_unet_v2(model_path)
% EVALUATE_UNET_V2
% Run trained network on the held-out test split. Reports per-class Dice
% on raw network output and on DP-refined boundaries, saves visualizations.

% -------- Config ---------------------------------------------------------
split_file = 'C:\OCT\Chosen Ones\preprocessed\use\segment\dataset_split_v2.mat';
trained_dir= 'C:\OCT\Chosen Ones\preprocessed\use\segment\trained_v2';
out_dir    = 'C:\OCT\Chosen Ones\preprocessed\use\segment\eval_v2';

dp_lambda  = 0.1;
dp_jump    = 5;
% -------------------------------------------------------------------------

if ~exist(out_dir, 'dir'); mkdir(out_dir); end

% --- Load model & split ------------------------------------------------
if nargin < 1 || isempty(model_path)
    files = dir(fullfile(trained_dir, 'unet_v2_*.mat'));
    if isempty(files); error('No trained model found in %s', trained_dir); end
    [~, ix] = max([files.datenum]);
    model_path = fullfile(trained_dir, files(ix).name);
end
fprintf('Loading model: %s\n', model_path);
M = load(model_path);
net = M.net;
labelIDs   = M.labelIDs;
target_size = M.target_size;

S = load(split_file);
test = S.test;
fprintf('Test images: %d\n', numel(test.img));

n = numel(test.img);
dice_raw  = nan(n, 3);
dice_dp   = nan(n, 2);
thick_sc  = nan(n, 1);
thick_ed  = nan(n, 1);

for i = 1:n
    img = imread(test.img{i});
    if size(img, 3) == 3; img = rgb2gray(img); end
    lbl_png = imread(test.lbl{i});

    img_r = imresize(img, target_size, 'bilinear');
    lbl_r = imresize(lbl_png, target_size, 'nearest');

    % --- Forward pass: feed network in SAME range as training (0-255) ----
    % Training fed uint8 images directly via pixelLabelDatastore + transform,
    % so weights expect inputs in 0-255 range, NOT 0-1.
    X = single(img_r);
    X = dlarray(X, 'SSCB');
    if canUseGPU; X = gpuArray(X); end
    Y = predict(net, X);
    Y = extractdata(gather(Y));
    prob = double(Y);

    [~, pred_raw] = max(prob, [], 3);
    pred_raw = uint8(pred_raw - 1);
    for c = 1:3
        dice_raw(i, c) = dice_score(pred_raw == labelIDs(c), lbl_r == labelIDs(c));
    end

    [top_sc, bot_sc, end_ed] = extract_boundaries_dp(prob, dp_lambda, dp_jump);
    pred_dp = build_mask_from_boundaries(top_sc, bot_sc, end_ed, target_size);
    dice_dp(i, 1) = dice_score(pred_dp == 1, lbl_r == 1);
    dice_dp(i, 2) = dice_score(pred_dp == 2, lbl_r == 2);

    thick_sc(i) = mean(bot_sc - top_sc);
    thick_ed(i) = mean(end_ed - bot_sc);

    if isfield(test, 'base')
        base = test.base{i};
    else
        [~, base, ~] = fileparts(test.img{i});
        base = erase(base, '_proc');
    end
    save_eval_figure(img_r, lbl_r, pred_raw, ...
        top_sc, bot_sc, end_ed, dice_raw(i,:), dice_dp(i,:), ...
        fullfile(out_dir, [base '_eval.png']), base);

    fprintf('  [%2d/%2d] %-20s : raw SC=%.3f ED=%.3f | DP SC=%.3f ED=%.3f\n', ...
        i, n, base, dice_raw(i,2), dice_raw(i,3), dice_dp(i,1), dice_dp(i,2));
end

fprintf('\n========== Test Set Results ==========\n');
fprintf('Raw argmax:\n');
fprintf('  bg Dice : %.3f +/- %.3f\n', mean(dice_raw(:,1)), std(dice_raw(:,1)));
fprintf('  SC Dice : %.3f +/- %.3f\n', mean(dice_raw(:,2)), std(dice_raw(:,2)));
fprintf('  ED Dice : %.3f +/- %.3f\n', mean(dice_raw(:,3)), std(dice_raw(:,3)));
fprintf('DP-refined boundaries:\n');
fprintf('  SC Dice : %.3f +/- %.3f\n', mean(dice_dp(:,1)), std(dice_dp(:,1)));
fprintf('  ED Dice : %.3f +/- %.3f\n', mean(dice_dp(:,2)), std(dice_dp(:,2)));
fprintf('Thickness (pixels @ %dx%d):\n', target_size(1), target_size(2));
fprintf('  SC : %.2f +/- %.2f px\n', mean(thick_sc), std(thick_sc));
fprintf('  ED : %.2f +/- %.2f px\n', mean(thick_ed), std(thick_ed));
fprintf('\nv1 comparison: SC=0.803, ED=0.870 (with pseudo-labels, 84 imgs)\n');

metrics_path = fullfile(out_dir, 'test_metrics.mat');
files = test.img(:); %#ok<NASGU>
save(metrics_path, 'dice_raw', 'dice_dp', 'thick_sc', 'thick_ed', 'files');
fprintf('\nSaved metrics -> %s\n', metrics_path);
fprintf('Saved per-image figures in %s\n', out_dir);
end

% =========================================================================
function d = dice_score(A, B)
A = logical(A); B = logical(B);
inter = nnz(A & B);
denom = nnz(A) + nnz(B);
if denom == 0; d = 1; else; d = 2 * inter / denom; end
end

% =========================================================================
function mask = build_mask_from_boundaries(top_sc, bot_sc, end_ed, sz)
H = sz(1); W = sz(2);
mask = zeros(H, W, 'uint8');
for c = 1:W
    r1 = max(1, min(H, round(top_sc(c))));
    r2 = max(1, min(H, round(bot_sc(c))));
    r3 = max(1, min(H, round(end_ed(c))));
    mask(r1:r2, c) = 1;
    if r3 > r2; mask(r2+1:r3, c) = 2; end
end
end

% =========================================================================
function save_eval_figure(img, gt, pred_raw, top_sc, bot_sc, end_ed, ...
                          dr, dd, out_path, ttl)
fig = figure('Visible','off','Position',[100 100 1600 900]);
tiledlayout(fig, 2, 2, 'TileSpacing','compact','Padding','compact');

nexttile; imshow(img, []);
title(sprintf('Input - %s', ttl), 'Interpreter','none');

nexttile; imshow(label2rgb(gt+1, [0 0 0; 1 0.3 0.3; 0.3 1 0.3]));
title('Ground Truth (red=SC, green=ED)');

nexttile; imshow(label2rgb(pred_raw+1, [0 0 0; 1 0.3 0.3; 0.3 1 0.3]));
title(sprintf('Raw argmax  Dice SC=%.3f ED=%.3f', dr(2), dr(3)));

nexttile; imshow(img, []); hold on;
plot(1:numel(top_sc), top_sc, 'r-', 'LineWidth', 1.5);
plot(1:numel(bot_sc), bot_sc, 'y-', 'LineWidth', 1.5);
plot(1:numel(end_ed), end_ed, 'g-', 'LineWidth', 1.5);
hold off;
title(sprintf('DP boundaries  Dice SC=%.3f ED=%.3f', dd(1), dd(2)));
legend('top SC','bot SC','end ED','Location','southeast','TextColor','w');

exportgraphics(fig, out_path, 'Resolution', 100);
close(fig);
end