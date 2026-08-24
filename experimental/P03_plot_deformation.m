function P03_plot_deformation(folder)
% P03_PLOT_DEFORMATION
% Non-interactive overview plot of the four time-series signals from the
% U-Net pipeline output (timeseries.csv).
%
% Produces a 4-panel figure:
%   (1) Boundary positions in pixels (top_sc, bot_sc, end_ed)
%   (2) SC layer thickness over time
%   (3) ED layer thickness over time
%   (4) Surface displacement of top_SC (the indentation depth used by Hayes)
%
% Vertical dotted lines mark sub_idx (sub-folder) boundaries so you can see
% where one scan ends and the next begins.
%
% Usage:
%   P03_plot_deformation('C:\OCT\test\2_analysis')
%
% Output:
%   <folder>\P03_deformation.png
%
% Reads:
%   <folder>\timeseries.csv  (produced by the segmentation EXE)

if nargin < 1, folder = pwd; end

% --------- USER SETTINGS ---------
PX_PER_MM = 200;
FPS       = 25;     % 500 frames in 20 s
% ---------------------------------

csv_path = fullfile(folder, 'timeseries.csv');
if ~exist(csv_path, 'file')
    error('timeseries.csv not found in %s', folder);
end
fprintf('Loading: %s\n', csv_path);

T = readtable(csv_path);
needed = {'top_sc_px','bot_sc_px','end_ed_px', ...
          'sc_thickness_mm','ed_thickness_mm', ...
          'total_thickness_mm','surface_disp_mm','sub_idx'};
miss = needed(~ismember(needed, T.Properties.VariableNames));
if ~isempty(miss)
    error('CSV missing columns: %s', strjoin(miss, ', '));
end

n = height(T);
t = (0:n-1)' / FPS;

% Where does each sub_idx start?
sub_breaks = find(diff(T.sub_idx) ~= 0) + 1;

% --- Build figure -------------------------------------------------------
fig = figure('Color','w','Position',[40 30 1200 950], ...
    'Name','P03 - Deformation overview');
tlay = tiledlayout(fig, 4, 1, 'TileSpacing','compact','Padding','compact');

% Panel 1: boundaries
ax1 = nexttile;
plot(t, T.top_sc_px, 'r-', 'LineWidth',1.2); hold on;
plot(t, T.bot_sc_px, '-', 'Color',[0.95 0.85 0],'LineWidth',1.2);
plot(t, T.end_ed_px, 'g-', 'LineWidth',1.2);
set(ax1, 'YDir','reverse');
ylabel('Depth (px)');
title(sprintf('Boundary positions  (%d frames @ %d fps, %d px/mm)', ...
    n, FPS, PX_PER_MM));
legend({'top SC','bot SC','end ED'}, 'Location','best');
grid on;

% Panel 2: SC thickness
ax2 = nexttile;
plot(t, T.sc_thickness_mm * 1000, '-', 'Color',[0.85 0.2 0.2], 'LineWidth',1.1);
ylabel('SC thickness (\mum)');
title('Stratum corneum (top SC \rightarrow bot SC)');
grid on;

% Panel 3: ED thickness
ax3 = nexttile;
plot(t, T.ed_thickness_mm * 1000, '-', 'Color',[0.2 0.6 0.2], 'LineWidth',1.1);
ylabel('ED thickness (\mum)');
title('Epidermis (bot SC \rightarrow end ED)');
grid on;

% Panel 4: surface displacement (THIS is what Hayes uses as 'w')
ax4 = nexttile;
plot(t, T.surface_disp_mm * 1000, '-', 'Color',[0.2 0.4 0.7], 'LineWidth',1.2);
ylabel('Surface disp (\mum)');
xlabel('Time (s)');
title('Surface displacement of top SC (= indentation depth w for Hayes)');
grid on;

% Common cosmetics: link x, draw sub_idx breaks on every panel
linkaxes([ax1 ax2 ax3 ax4], 'x');
xlim(ax4, [t(1) t(end)]);
for ax = [ax1 ax2 ax3 ax4]
    yl = ylim(ax);
    hold(ax,'on');
    for k = 1:numel(sub_breaks)
        xb = t(sub_breaks(k));
        plot(ax, [xb xb], yl, 'k:', 'LineWidth',0.5, 'HandleVisibility','off');
    end
    ylim(ax, yl);
end

% --- Print summary ------------------------------------------------------
fprintf('\nQuick stats:\n');
fprintf('  SC thickness    : %.1f +/- %.1f um   (range %.1f - %.1f)\n', ...
    1000*mean(T.sc_thickness_mm), 1000*std(T.sc_thickness_mm), ...
    1000*min(T.sc_thickness_mm),  1000*max(T.sc_thickness_mm));
fprintf('  ED thickness    : %.1f +/- %.1f um   (range %.1f - %.1f)\n', ...
    1000*mean(T.ed_thickness_mm), 1000*std(T.ed_thickness_mm), ...
    1000*min(T.ed_thickness_mm),  1000*max(T.ed_thickness_mm));
fprintf('  Total thickness : %.1f +/- %.1f um\n', ...
    1000*mean(T.total_thickness_mm), 1000*std(T.total_thickness_mm));
fprintf('  Surface disp    : %.1f - %.1f um   (peak at t=%.2fs)\n', ...
    1000*min(T.surface_disp_mm), 1000*max(T.surface_disp_mm), ...
    t(find(T.surface_disp_mm == max(T.surface_disp_mm), 1)));

out_png = fullfile(folder, 'P03_deformation.png');
exportgraphics(fig, out_png, 'Resolution', 150);
fprintf('\nSaved: %s\n', out_png);
fprintf('Next: P04_pick_cycle(''%s'')\n', folder);

end