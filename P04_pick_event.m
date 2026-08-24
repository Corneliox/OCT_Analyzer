% =========================================================================
%  P04_pick_event.m   (v3)
%  -----------------------------------------------------------------
%  Single-file replacement for the old P03 + P04 + P05 pipeline.
%
%  CHANGES vs v2
%    - Forces a LIGHT plot theme via groot defaults at the top of the
%      script, then sets axes colors explicitly per figure. Fixes the
%      black-background issue in MATLAB R2025b's dark theme.
%    - ALWAYS shows E1, E2, E3 by polyfit extrapolation:
%         filled square = within observed deformation (reliable)
%         hollow square = extrapolated beyond observed (* in label)
%      The polyfit curve is solid within data range, dashed gray outside.
%
%  INPUT
%    timeseries.csv  with columns top_sc_px, bot_sc_px, end_ed_px,
%                    sc_thickness_mm, ed_thickness_mm, total_thickness_mm
%    timeseries.png  (optional) reference image
%
%  WORKFLOW
%    1. Force light theme defaults.
%    2. Reference PNG in its own small window.
%    3. Big picking figure with the 3 contour lines.
%    4. Click 4x: START left, START right, PEAK left, PEAK right.
%       Clicks outside the axes are ignored and re-prompted.
%    5. Auto-detect:
%         start_frame = arg min(top_sc) inside [c1,c2], rightmost on tie
%         peak_frame  = arg max(end_ed) inside [c3,c4], leftmost  on tie
%    6. Slice [start..peak], resample to 101 points, build artificial
%       pressure ramp linspace(0,1,101).
%    7. Hayes/Zheng-Mak moduli at 5/10/15% strain for SC, ED, full skin.
%       Extrapolated points marked with hollow markers.
%    8. One result figure per region.
%    9. Save xy_data.mat, results.csv, PNGs.
%
%  Pressure is unitless (0..1); E values are arbitrary units.
%  Swap pressure101 for the real load-cell signal to get MPa.
% =========================================================================

clc; clear; close all;

%% --- 0. Force light plot theme (overrides R2025b dark mode) -----------
set(groot, 'DefaultFigureColor'    , 'w');
set(groot, 'DefaultAxesColor'      , 'w');
set(groot, 'DefaultAxesXColor'     , 'k');
set(groot, 'DefaultAxesYColor'     , 'k');
set(groot, 'DefaultAxesZColor'     , 'k');
set(groot, 'DefaultAxesGridColor'  , [.3 .3 .3]);
set(groot, 'DefaultTextColor'      , 'k');
set(groot, 'DefaultLegendColor'    , 'w');
set(groot, 'DefaultLegendTextColor', 'k');
set(groot, 'DefaultLegendEdgeColor', 'k');

%% --- 1. Configuration --------------------------------------------------
csv_path  = 'C:\OCT\test\2_analysis\timeseries.csv';
img_path  = 'C:\OCT\test\2_analysis\timeseries.png';

px_per_mm     = 200;
nu            = 0.45;
a_indenter    = 2.5;
strain_ratios = [0.05 0.10 0.15];
N_resample    = 101;
save_results  = true;

kappa_tbl = [0.2 1.252; 0.4 1.599; 0.6 2.031; 0.8 2.532; 1.0 3.085;
             1.5 4.638; 2.0 6.380; 2.5 8.265; 3.0 10.260; 3.5 12.320;
             4.0 14.450; 5.0 18.800; 6.0 23.230; 7.0 27.690; 8.0 32.150];

%% --- 2. Load -----------------------------------------------------------
T = readtable(csv_path);
top_sc  = T.top_sc_px;
bot_sc  = T.bot_sc_px;
end_ed  = T.end_ed_px;
N       = height(T);
frames  = (1:N)';
fprintf('Loaded %d frames from %s\n', N, csv_path);

%% --- 3. Reference image (separate window) ------------------------------
if isfile(img_path)
    fref = figure('Name','Reference (read-only)','NumberTitle','off', ...
        'Color','w','Units','normalized','Position',[0.02 0.55 0.32 0.4]);
    imshow(imread(img_path));
    title('Reference - 5 pressure peaks visible','Color','k');
end

%% --- 4. Picking figure -------------------------------------------------
fpick = figure('Name','Pick start/peak','NumberTitle','off','Color','w', ...
    'Units','normalized','Position',[0.05 0.08 0.9 0.82]);
ax = axes(fpick, 'Color','w','XColor','k','YColor','k','GridColor',[.3 .3 .3]);
plot(ax, frames, top_sc, 'r-' , 'LineWidth', 1.4); hold(ax,'on');
plot(ax, frames, bot_sc, 'Color',[0.85 0.65 0], 'LineWidth', 1.4);
plot(ax, frames, end_ed, 'Color',[0 0.55 0]   , 'LineWidth', 1.4);
set(ax, 'YDir', 'reverse');
xlabel(ax,'Frame index','Color','k');
ylabel(ax,'Depth (px)' ,'Color','k');
lg = legend(ax, {'top SC','bot SC','end ED'}, 'Location','best');
set(lg,'Color','w','TextColor','k','EdgeColor','k');
grid(ax,'on');
title(ax, ['Click  1) START left   2) START right   3) PEAK left   ' ...
    '4) PEAK right    (clicks outside the axes are ignored)'], 'Color','k');

% --- waitforbuttonpress loop with bounds check ---
prompts = {'START left bound','START right bound', ...
           'PEAK  left bound','PEAK  right bound'};
clicks  = zeros(4,2);
c = 0;
while c < 4
    fprintf('Click %d/4: %s ...\n', c+1, prompts{c+1});
    figure(fpick);
    waitforbuttonpress;
    cp = get(ax, 'CurrentPoint');
    xc = cp(1,1); yc = cp(1,2);
    xl = xlim(ax); yl = ylim(ax);
    if xc < xl(1) || xc > xl(2) || yc < yl(1) || yc > yl(2)
        fprintf('   (outside axes, ignored - click again)\n');
        continue;
    end
    c = c + 1;
    clicks(c,:) = [xc, yc];
    plot(ax, xc, yc, 'kx', 'MarkerSize', 14, 'LineWidth', 2.5);
    drawnow;
end

% Sanitize bounds
xs1 = max(1, min(N, round(min(clicks(1:2,1)))));
xs2 = max(1, min(N, round(max(clicks(1:2,1)))));
xp1 = max(1, min(N, round(min(clicks(3:4,1)))));
xp2 = max(1, min(N, round(max(clicks(3:4,1)))));

% START: min top_sc in [xs1,xs2], rightmost on tie
top_win  = top_sc(xs1:xs2);
last_idx = find(top_win == min(top_win), 1, 'last');
start_frame = xs1 + last_idx - 1;

% PEAK: max end_ed in [xp1,xp2], leftmost on tie
ed_win    = end_ed(xp1:xp2);
first_idx = find(ed_win == max(ed_win), 1, 'first');
peak_frame = xp1 + first_idx - 1;

xline(ax, start_frame, 'b-', sprintf('START %d',start_frame),'LineWidth',1.5);
xline(ax, peak_frame , 'm-', sprintf('PEAK %d', peak_frame ),'LineWidth',1.5);
plot(ax, start_frame, top_sc(start_frame),'bo','MarkerFaceColor','b','MarkerSize',9);
plot(ax, peak_frame , end_ed(peak_frame ),'mo','MarkerFaceColor','m','MarkerSize',9);

fprintf('\n--> START frame = %d  (window %d..%d)\n', start_frame, xs1, xs2);
fprintf('--> PEAK  frame = %d  (window %d..%d)\n\n', peak_frame , xp1, xp2);

if peak_frame <= start_frame
    error('PEAK must be after START. Re-run.');
end

%% --- 5. Build deformation (baseline = mean over start-click window) ---
idx_event    = start_frame:peak_frame;
idx_baseline = xs1:xs2;

sc_th_full   = T.sc_thickness_mm;
ed_th_full   = T.ed_thickness_mm;
full_th_full = T.total_thickness_mm;

h0_sc   = mean(sc_th_full  (idx_baseline));
h0_ed   = mean(ed_th_full  (idx_baseline));
h0_full = mean(full_th_full(idx_baseline));

sc_def   = h0_sc   - sc_th_full  (idx_event);
ed_def   = h0_ed   - ed_th_full  (idx_event);
full_def = h0_full - full_th_full(idx_event);

% Resample to 101 points
xq = linspace(0, 1, N_resample);
xp = linspace(0, 1, numel(idx_event));
sc_def101   = interp1(xp, sc_def  , xq, 'linear')';
ed_def101   = interp1(xp, ed_def  , xq, 'linear')';
full_def101 = interp1(xp, full_def, xq, 'linear')';

% Artificial pressure 0..1 (placeholder)
pressure101 = linspace(0, 1, N_resample)';

%% --- 6. Hayes per region (always compute, mark extrapolated) ----------
regions(1) = struct('name','Stratum Corneum (SC)','h0',h0_sc  ,'def',sc_def101  );
regions(2) = struct('name','Epidermis (ED)'      ,'h0',h0_ed  ,'def',ed_def101  );
regions(3) = struct('name','Full skin'           ,'h0',h0_full,'def',full_def101);

results = nan(3,7);                % E1 E2 E3 E23 h0 a/h kappa
for r = 1:3
    h0      = regions(r).h0;
    def     = regions(r).def;
    max_def = max(def);

    p2    = polyfit(def, pressure101, 2);
    a_h   = a_indenter / h0;
    kappa = interp1(kappa_tbl(:,1), kappa_tbl(:,2), a_h, 'linear', 'extrap');
    e_factor = (1 - nu^2) / (2 * a_indenter * kappa) * 9.807;

    Wv = h0 * strain_ratios;             % requested deformations (mm)
    Fv = polyval(p2, Wv);                % polyfit extrapolated if needed
    Ev = (Fv ./ Wv) * e_factor;
    is_extrap = Wv > max_def;            % flag which points are extrapolated
    E23 = (Fv(3) - Fv(2)) / (Wv(3) - Wv(2)) * e_factor;

    regions(r).p2         = p2;        regions(r).E         = [Ev E23];
    regions(r).F          = Fv;        regions(r).W         = Wv;
    regions(r).is_extrap  = is_extrap; regions(r).kappa     = kappa;
    regions(r).max_def    = max_def;   regions(r).max_strain= max_def / h0;
    results(r,:) = [Ev, E23, h0, a_h, kappa];

    if max_def <= 0
        warning('%s: max deformation = %.4f mm. Segmentation noise > signal in this event.', ...
            regions(r).name, max_def);
    elseif max_def < h0 * 0.15
        fprintf('NOTE: %s reached %.1f%% strain; E_k beyond that are extrapolated.\n', ...
            regions(r).name, 100*max_def/h0);
    end
    if a_h > 8
        fprintf('NOTE: %s a/h = %.1f > 8 (kappa table maxes at 8); kappa extrapolated.\n', ...
            regions(r).name, a_h);
    end
end

%% --- 7. Result figures (one per region, separate windows) -------------
posL = {[0.05 0.08 0.30 0.4], [0.36 0.08 0.30 0.4], [0.67 0.08 0.30 0.4]};
cols = lines(3);
for r = 1:3
    fr = figure('Name', regions(r).name, 'Color','w','NumberTitle','off', ...
        'Units','normalized','Position', posL{r});
    axR = axes(fr, 'Color','w','XColor','k','YColor','k','GridColor',[.3 .3 .3]);
    hold(axR,'on');

    def = regions(r).def;
    p2  = regions(r).p2;

    % Scatter of all 101 points (interpolated samples along loading curve)
    plot(axR, def, pressure101, 'o', 'MarkerEdgeColor', [.2 .2 .2], ...
        'MarkerFaceColor', [.7 .7 .7], 'MarkerSize', 5);

    % Curve: solid in data range, dashed gray for extrapolation either side
    xmin_curve = min([min(def), 0, regions(r).W]);
    xmax_curve = max([max(def),    regions(r).W]);
    xi = linspace(xmin_curve, xmax_curve, 400);
    fi = polyval(p2, xi);
    in_range = xi >= min(def) & xi <= max(def);
    if any(~in_range & xi < min(def))
        m = ~in_range & xi < min(def);
        plot(axR, xi(m), fi(m), '--', 'Color',[.5 .5 .5], 'LineWidth',1.3);
    end
    plot(axR, xi(in_range), fi(in_range), 'k-', 'LineWidth', 2);
    if any(~in_range & xi > max(def))
        m = ~in_range & xi > max(def);
        plot(axR, xi(m), fi(m), '--', 'Color',[.5 .5 .5], 'LineWidth',1.3);
    end

    % E_k markers - filled if in range, hollow with * label if extrapolated
    for k = 1:3
        if regions(r).is_extrap(k)
            plot(axR, regions(r).W(k), regions(r).F(k), 's', ...
                'MarkerEdgeColor', cols(k,:), 'MarkerFaceColor', 'w', ...
                'MarkerSize', 12, 'LineWidth', 2);
            lbl = sprintf('  E_%d=%.2f*', k, regions(r).E(k));
        else
            plot(axR, regions(r).W(k), regions(r).F(k), 's', ...
                'MarkerEdgeColor', 'k', 'MarkerFaceColor', cols(k,:), ...
                'MarkerSize', 11);
            lbl = sprintf('  E_%d=%.2f', k, regions(r).E(k));
        end
        text(axR, regions(r).W(k), regions(r).F(k), lbl, ...
            'Color', cols(k,:), 'FontWeight','bold');
    end

    xlabel(axR,'Deformation (mm)','Color','k');
    ylabel(axR,'Pressure (artificial 0..1)','Color','k');
    e23s = sprintf('%.2f', regions(r).E(4));
    if regions(r).is_extrap(2) || regions(r).is_extrap(3)
        e23s = [e23s '*'];
    end
    title(axR, sprintf( ...
        '%s   h_0=%.3f mm   max strain=%.1f%%   E_{23}=%s    (* = extrapolated)', ...
        regions(r).name, regions(r).h0, 100*regions(r).max_strain, e23s), ...
        'Color','k');
    grid(axR,'on');
end

%% --- 8. Console + save -------------------------------------------------
fprintf('\n====================  RESULTS  ====================\n');
fprintf('%-22s %8s %8s %8s %8s %8s %8s %8s\n', ...
    'Region','E1','E2','E3','E23','h0(mm)','a/h','kappa');
labels = {'SC','ED','FullSkin'};
for r = 1:3
    fprintf('%-22s %8.3f %8.3f %8.3f %8.3f %8.3f %8.3f %8.3f\n', ...
        regions(r).name, results(r,:));
end
fprintf('====================================================\n');
fprintf('Pressure is artificial 0..1; E values are arbitrary units.\n');
fprintf('Hollow markers / asterisks = extrapolated beyond observed deformation.\n');
fprintf('Replace pressure101 with the real load-cell signal to get MPa.\n\n');

if save_results
    save('xy_data.mat', 'clicks', 'start_frame', 'peak_frame', ...
        'idx_baseline', 'pressure101', 'regions', 'results');
    Tout = array2table(results, ...
        'VariableNames', {'E1','E2','E3','E23','h0_mm','a_over_h','kappa'}, ...
        'RowNames', labels);
    writetable(Tout, 'results.csv', 'WriteRowNames', true);

    saveas(fpick, 'P04_result_picking.png');
    figs = findobj('Type','figure');
    region_names = {regions.name};
    for f = 1:numel(figs)
        nm = get(figs(f),'Name');
        if any(strcmp(nm, region_names))
            saveas(figs(f), ['P04_result_' matlab.lang.makeValidName(nm) '.png']);
        end
    end
    fprintf('Saved xy_data.mat, results.csv, P04_result_*.png\n');
end