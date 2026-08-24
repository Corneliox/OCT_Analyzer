% =========================================================================
% P04_pickloading.m  (v9)
% Pick one clean loading cycle from U-Net pipeline timeseries.csv,
% generate artificial force (0 -> 1), polyfit force-vs-deformation.
%
% Replaces Gilang's P04_pilihtitik.m for the new pipeline.
%
% v9 fix (CRITICAL):
%   - When mouse moves over the boundary panel (above deformation panel),
%     ax_def.CurrentPoint projects to huge y-values. v8 set those as the
%     horizontal guide's YData, which auto-rescaled the axes (because
%     'axis padded' sets limits but does NOT set XLimMode/YLimMode='manual').
%     This caused a runaway feedback loop: rescaled axes -> bigger
%     projected y -> bigger rescale, until the data was flattened at the
%     bottom of a 10^27 μm tall plot.
%   - Fix: lock axes limits to manual mode immediately after axis padded.
%     Add bounds checks in motion callback so guides hide and cursor text
%     stays meaningful when mouse leaves a panel.
%
% v8: dropped ginput entirely (R2024a UIControlController bug breaks the
%     cursor); switched to typed values via input() with mouse-tracked
%     magenta guide lines drawn directly into the axes.
%
% Earlier-version notes:
%   - Single FOLDER setting; auto-finds timeseries.csv.
%   - Boundary plot (top SC / bot SC / end ED) drawn from CSV directly,
%     time axis linked to deformation panel.
%   - surface_disp_mm as deformation; force is artificial 0->1.
%   - All units in micrometers.
%   - Computes & stores R^2 of polyfit; warns if poor.
% =========================================================================

clc; clear; close all;

% --------- USER SETTINGS ---------
folder    = 'C:\OCT\test\2_analysis';     % <-- only thing to edit per run
PX_PER_MM = 200;
FPS       = 25;
R2_WARN   = 0.95;
GUIDE_COL = [1 0 1];                       % magenta crosshair guide colour
% ---------------------------------

PX_TO_UM = 1000 / PX_PER_MM;

csv_path = fullfile(folder, 'timeseries.csv');
png_path = fullfile(folder, 'timeseries.png');
out_dir  = folder;

if ~exist(folder, 'dir'),    error('Folder not found: %s', folder); end
if ~exist(csv_path, 'file'), error('timeseries.csv not found in: %s', folder); end

% ---------- 1. Load CSV + validate columns ----------
fprintf('Folder:  %s\n', folder);
fprintf('CSV:     %s\n', csv_path);

T = readtable(csv_path);
needed = {'surface_disp_mm','total_thickness_mm','top_sc_px','bot_sc_px','end_ed_px'};
missing = needed(~ismember(needed, T.Properties.VariableNames));
if ~isempty(missing)
    error('timeseries.csv is missing required columns: %s', strjoin(missing, ', '));
end

n_frames = height(T);
time_s   = (0:n_frames-1)' / FPS;
deformation_um     = T.surface_disp_mm   * 1000;
total_thickness_um = T.total_thickness_mm * 1000;

% ---------- 2. Build figure ----------
fig = figure('Color','w','Position',[60 40 1200 950], ...
    'Name','P04 - Pick loading window');

% Panel 1: boundary positions
ax_bnd = subplot(4,1,1);
h_top = plot(time_s, T.top_sc_px, 'r-', 'LineWidth',1.3); hold on;
h_bot = plot(time_s, T.bot_sc_px, '-', 'Color',[0.95 0.85 0], 'LineWidth',1.3);
h_end = plot(time_s, T.end_ed_px, 'g-', 'LineWidth',1.3);
set(ax_bnd, 'YDir','reverse');
xlabel('Time (s)'); ylabel('Depth (px)');
title('Boundary positions: red = top SC (surface) | yellow = bot SC | green = end ED');
legend([h_top h_bot h_end], {'top SC','bot SC','end ED'}, 'Location','best');
grid on;
axis(ax_bnd, 'padded');
% LOCK limits so motion-callback line updates don't rescale the axes
set(ax_bnd, 'XLimMode','manual', 'YLimMode','manual');

% Panels 2/3/4
ax1 = subplot(4,1,2);
ax2 = subplot(4,1,3);
ax3 = subplot(4,1,4);

axes(ax1);
plot(time_s, deformation_um, '-', 'Color',[0.2 0.4 0.7], 'LineWidth',1.2);
hold on; grid on;
xlabel('Time (s)'); ylabel('Surface displacement (\mum)');
title(sprintf('Deformation time series — %d frames, %.1f s', n_frames, time_s(end)));
axis(ax1, 'padded');
% LOCK limits — this is the critical fix for the runaway rescale bug
set(ax1, 'XLimMode','manual', 'YLimMode','manual');

linkaxes([ax_bnd, ax1], 'x');

% ---------- 3. Mouse-tracked crosshair guides ----------
guide_v_def = line('XData',[NaN NaN], 'YData',[NaN NaN], 'Parent',ax1, ...
    'Color',GUIDE_COL, 'LineWidth',0.8, 'HandleVisibility','off');
guide_h_def = line('XData',[NaN NaN], 'YData',[NaN NaN], 'Parent',ax1, ...
    'Color',GUIDE_COL, 'LineWidth',0.8, 'HandleVisibility','off');
guide_v_bnd = line('XData',[NaN NaN], 'YData',[NaN NaN], 'Parent',ax_bnd, ...
    'Color',GUIDE_COL, 'LineWidth',0.8, 'HandleVisibility','off');
cursor_text = text(0.01, 0.96, '  move mouse over plot  ', 'Parent',ax1, ...
    'Units','normalized', 'FontSize',11, 'FontWeight','bold', ...
    'Color',GUIDE_COL, 'BackgroundColor',[0 0 0 0.7], 'EdgeColor',GUIDE_COL);

set(fig, 'WindowButtonMotionFcn', ...
    @(~,~) p04_xhair(ax1, ax_bnd, guide_v_def, guide_h_def, guide_v_bnd, cursor_text));

drawnow;

% ---------- 4. Get values via command-line input ----------
fprintf('\n========================================================\n');
fprintf(' Mouse over the figure: magenta crosshair shows your\n');
fprintf(' position. Cursor coords are at top-left of the\n');
fprintf(' deformation panel (t = ... s, y = ... um).\n');
fprintf('\n');
fprintf(' Find one clean loading cycle:\n');
fprintf('   - Baseline: a flat, no-pressure stretch BEFORE a push.\n');
fprintf('   - Peak:     the moment of max compression in that push.\n');
fprintf('\n');
fprintf(' For each, give a SEARCH RANGE (left/right time in seconds);\n');
fprintf(' the script auto-finds the exact baseline (rightmost min) and\n');
fprintf(' peak (max) inside the range, so the range can be loose.\n');
fprintf('========================================================\n\n');

xbA_in = input('Baseline range LEFT  (s) : ');
xbB_in = input('Baseline range RIGHT (s) : ');
if isempty(xbA_in) || isempty(xbB_in)
    error('Baseline range bounds are required.');
end
xbA = min(xbA_in, xbB_in);  xbB = max(xbA_in, xbB_in);
xline(ax1,    xbA, ':', 'Color',[0 0.6 0], 'LineWidth',1.2, 'HandleVisibility','off');
xline(ax1,    xbB, ':', 'Color',[0 0.6 0], 'LineWidth',1.2, 'HandleVisibility','off');
xline(ax_bnd, xbA, ':', 'Color',[0 0.6 0], 'LineWidth',1.2, 'HandleVisibility','off');
xline(ax_bnd, xbB, ':', 'Color',[0 0.6 0], 'LineWidth',1.2, 'HandleVisibility','off');

[~, iL] = min(abs(time_s - xbA));
[~, iR] = min(abs(time_s - xbB));
seg_b      = deformation_um(iL:iR);
min_b      = min(seg_b);
last_min_i = find(seg_b == min_b, 1, 'last');
idx_base   = iL + last_min_i - 1;
y_base     = deformation_um(idx_base);

plot(ax1, time_s(idx_base), y_base, 'go', 'MarkerSize',14, 'LineWidth',2.5, ...
    'HandleVisibility','off');
text(ax1, time_s(idx_base), y_base+15, ' baseline', ...
    'Color',[0 0.6 0], 'FontWeight','bold');
fprintf('  -> baseline: frame %d, t=%.2fs, displacement=%.2f um\n\n', ...
    idx_base, time_s(idx_base), y_base);

xpA_in = input('Peak range LEFT  (s) : ');
xpB_in = input('Peak range RIGHT (s) : ');
if isempty(xpA_in) || isempty(xpB_in)
    error('Peak range bounds are required.');
end
xpA = min(xpA_in, xpB_in);  xpB = max(xpA_in, xpB_in);
xline(ax1,    xpA, ':', 'Color','r', 'LineWidth',1.2, 'HandleVisibility','off');
xline(ax1,    xpB, ':', 'Color','r', 'LineWidth',1.2, 'HandleVisibility','off');
xline(ax_bnd, xpA, ':', 'Color','r', 'LineWidth',1.2, 'HandleVisibility','off');
xline(ax_bnd, xpB, ':', 'Color','r', 'LineWidth',1.2, 'HandleVisibility','off');

[~, jL] = min(abs(time_s - xpA));
[~, jR] = min(abs(time_s - xpB));
seg_p     = deformation_um(jL:jR);
max_p     = max(seg_p);
first_max_i = find(seg_p == max_p, 1, 'first');
idx_peak  = jL + first_max_i - 1;
y_peak    = deformation_um(idx_peak);

plot(ax1, time_s(idx_peak), y_peak, 'ro', 'MarkerSize',14, 'LineWidth',2.5, ...
    'HandleVisibility','off');
text(ax1, time_s(idx_peak), y_peak-15, ' peak', ...
    'Color','r', 'FontWeight','bold');
fprintf('  -> peak:     frame %d, t=%.2fs, displacement=%.2f um\n\n', ...
    idx_peak, time_s(idx_peak), y_peak);

if idx_peak <= idx_base
    error(['Peak frame (%d) is at or before baseline frame (%d). ', ...
           'Re-run with corrected ranges so peak comes after baseline.'], ...
        idx_peak, idx_base);
end

plot(ax1, time_s(idx_base:idx_peak), deformation_um(idx_base:idx_peak), ...
     'r-', 'LineWidth',2.5, 'HandleVisibility','off');

% ---------- 5. Slice + zero-baseline + artificial force ----------
window_idx = idx_base:idx_peak;
N_pts      = numel(window_idx);
defo_win   = deformation_um(window_idx) - deformation_um(idx_base);
artif_F    = linspace(0, 1, N_pts)';

fprintf('Loading window: frame %d -> %d (N=%d, %.2f s)\n', ...
    idx_base, idx_peak, N_pts, time_s(idx_peak)-time_s(idx_base));
fprintf('Deformation range: 0 -> %.2f um\n', defo_win(end));

axes(ax2);
plot(1:N_pts, artif_F, 'b-', 'LineWidth',1.5); grid on;
xlabel('Frame in window'); ylabel('Artificial force (a.u., 0-1)');
title(sprintf('Artificial force: linear 0->1 over %d frames', N_pts));
axis(ax2, 'padded');
set(ax2, 'XLimMode','manual', 'YLimMode','manual');

% ---------- 6. Resample to 101 pts + polyfit + R^2 ----------
xi_div = 100;
x_orig = linspace(0, xi_div, N_pts)';
xi     = (0:xi_div)';
defo100  = interp1(x_orig, defo_win, xi, 'linear');
force100 = interp1(x_orig, artif_F, xi, 'linear');
time100  = linspace(0, time_s(idx_peak)-time_s(idx_base), numel(xi))';

[p2, ~] = polyfit(defo100, force100, 2);
F_pred = polyval(p2, defo100);
ss_res = sum((force100 - F_pred).^2);
ss_tot = sum((force100 - mean(force100)).^2);
R2     = 1 - ss_res / max(ss_tot, eps);

fprintf('\nPolyfit (deg 2) on F vs deformation: R^2 = %.4f\n', R2);
if R2 < R2_WARN
    warning(['Polyfit R^2 = %.3f is below %.2f. The chosen cycle may be ', ...
             'noisy/non-monotonic, or the loading shape may not fit a ', ...
             'quadratic well. E1/E2/E3 from this fit will be unreliable.'], ...
             R2, R2_WARN);
end

axes(ax3);
plot(defo100, force100, 'k.', 'MarkerSize',10); hold on;
xi_fit = linspace(min(defo100), max(defo100), 200);
plot(xi_fit, polyval(p2, xi_fit), 'r-', 'LineWidth',2);
grid on;
xlabel('Deformation (\mum)'); ylabel('Force (a.u.)');
title(sprintf('Force vs Deformation (artificial F, polyfit deg 2, R^2 = %.4f)', R2));
legend({'Data (101 pts)','Polyfit'}, 'Location','best');
axis(ax3, 'padded');
set(ax3, 'XLimMode','manual', 'YLimMode','manual');

% ---------- 7. h via command-line input ----------
mean_baseline_th = mean(total_thickness_um(1:idx_base));
fprintf('\nBaseline-mean total thickness = %.2f um\n', mean_baseline_th);

h_input = input('Initial thickness h (um) [press Enter for baseline mean] : ', 's');
if isempty(strtrim(h_input))
    h_um = mean_baseline_th;
    src  = 'baseline mean';
else
    h_um = abs(str2double(h_input));
    if isnan(h_um) || h_um <= 0
        error('Invalid h value. Must be a positive number in micrometers.');
    end
    yline(ax1, h_um, '--k', sprintf(' h = %.1f um', h_um), ...
        'LabelHorizontalAlignment','left', 'HandleVisibility','off');
    src = 'manual entry';
end
fprintf('Using h = %.2f um (%s)\n', h_um, src);

% ---------- Clean up crosshair guides + position text before saving ----------
set(fig, 'WindowButtonMotionFcn', '');
delete([guide_v_def guide_h_def guide_v_bnd cursor_text]);

% ---------- 8. Save ----------
out = struct();
out.folder           = folder;
out.csv_path         = csv_path;
out.png_path         = png_path;
out.idx_base         = idx_base;
out.idx_peak         = idx_peak;
out.range_baseline_s = [xbA, xbB];
out.range_peak_s     = [xpA, xpB];
out.N_pts            = N_pts;
out.fps              = FPS;
out.deformation_um   = defo100;
out.force_au         = force100;
out.time_s           = time100;
out.polyfit_p2       = p2;
out.polyfit_R2       = R2;
out.h_um             = h_um;
out.h_source         = src;
out.px_per_mm        = PX_PER_MM;

save(fullfile(out_dir, 'xy_data_new.mat'), '-struct', 'out');
writematrix([time100, defo100, force100], fullfile(out_dir, 'young_input.csv'));
saveas(fig, fullfile(out_dir, 'P04_picking.png'));

fprintf('\nSaved (in %s):\n', out_dir);
fprintf('  xy_data_new.mat\n');
fprintf('  young_input.csv   (cols: time_s, defo_um, force_au)\n');
fprintf('  P04_picking.png\n');
fprintf('\nNext: run P05_calc_modulus  (uses xy_data_new.mat from same folder)\n');

% ============== local function: mouse motion crosshair ==============
function p04_xhair(ax_def, ax_bnd, gv_def, gh_def, gv_bnd, ctext)
    cp = get(ax_def, 'CurrentPoint');
    x = cp(1,1); y = cp(1,2);

    xl_def = get(ax_def, 'XLim');
    yl_def = get(ax_def, 'YLim');
    yl_bnd = get(ax_bnd, 'YLim');

    in_x = x >= xl_def(1) && x <= xl_def(2);
    in_y = y >= yl_def(1) && y <= yl_def(2);

    % Vertical guides (only when mouse is in valid time range)
    if in_x
        set(gv_def, 'XData',[x x], 'YData', yl_def);
        set(gv_bnd, 'XData',[x x], 'YData', yl_bnd);
    else
        set(gv_def, 'XData',[NaN NaN], 'YData',[NaN NaN]);
        set(gv_bnd, 'XData',[NaN NaN], 'YData',[NaN NaN]);
    end

    % Horizontal guide (only when mouse is in valid y range of deformation panel)
    if in_y
        set(gh_def, 'XData', xl_def, 'YData',[y y]);
    else
        set(gh_def, 'XData',[NaN NaN], 'YData',[NaN NaN]);
    end

    % Cursor text — show only meaningful values
    if in_x && in_y
        set(ctext, 'String', sprintf(' t = %.2f s   y = %.1f \\mum ', x, y));
    elseif in_x
        set(ctext, 'String', sprintf(' t = %.2f s   (mouse outside deformation panel)', x));
    else
        set(ctext, 'String', '  move mouse over plot  ');
    end
end