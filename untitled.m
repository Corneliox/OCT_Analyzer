%% 8. STIFFNESS (Young's Modulus E1 .. E20, each step = 5% strain)
% Physical limit: skin compresses max ~30% (= E6). Beyond E6 the power
% curve extrapolates and E values explode -- shown but flagged.

v_poisson = 0.45;
a_radius  = 2.5;       % indentor radius (mm)
k_factor  = 3.085;
g_gravity = 9.81;
part1 = (1 - v_poisson^2) / (2 * a_radius * k_factor);

t0_mm = thickness_um1(1) / 1000;   % initial thickness in mm

% Strain grid: 5%, 10%, ... 100%  (E1 .. E20)
strain_targets = (0.05:0.05:1.00)';
n_E   = numel(strain_targets);
w_all = strain_targets * t0_mm;    % displacement targets, mm

% Compute force and E at each strain from the power-law fit
P_gram = a_L_calc * (w_all .^ b_L);
P_N    = P_gram / 1000 * g_gravity;
E_kPa  = part1 * (P_N ./ w_all) * 1000;

% Physical validity cutoff
n_valid = 6;                       % E1..E6 = 5%..30% (skin limit)
n_fit   = 5;                       % linear regression uses E1..E5

% --- Linear regression through E1..E5 (force vs displacement) -------
p_lin = polyfit(w_all(1:n_fit), P_gram(1:n_fit), 1);
x_line = linspace(0, max(x_plot)*1.05, 100);
y_line = polyval(p_lin, x_line);

% --- Plot on the existing Force-vs-Displacement figure --------------
% (assumes the gca is still the hysteresis plot from Section 7)
hold on;

% Dashed regression line through E1..E5
plot(x_line, y_line, 'k--', 'LineWidth', 2, ...
    'DisplayName', sprintf('Linear fit E1-E5  (slope = %.3f g/mm)', p_lin(1)));

% Vertical line marking the 30% physical cutoff
xline(w_all(n_valid), ':', '30% strain (E6)', ...
    'Color', [0.4 0.4 0.4], 'LineWidth', 1.2, ...
    'LabelOrientation', 'horizontal', 'HandleVisibility', 'off');

% E1..E6 = filled yellow markers (valid)
plot(w_all(1:n_valid), P_gram(1:n_valid), 'ko', 'MarkerSize', 8, ...
    'MarkerFaceColor', 'y', 'DisplayName', 'E1..E6 (physical range)');

% E7..E20 = hollow grey markers (extrapolated)
plot(w_all(n_valid+1:end), P_gram(n_valid+1:end), 'o', ...
    'Color', [0.6 0.6 0.6], 'MarkerSize', 6, ...
    'DisplayName', 'E7..E20 (extrapolated)');

% Re-fit axes to include all points
xlim([0, max(w_all)*1.05]);
ylim([0, max(P_gram)*1.1]);
legend('Location', 'northwest');

% --- Print -----------------------------------------------------------
fprintf('\n--- Youngs Modulus (E1..E%d, 5%% strain steps) ---\n', n_E);
fprintf('Skin physical limit: ~30%% strain = E%d. Beyond = extrapolation.\n', n_valid);
fprintf('Linear regression through E1..E%d: slope = %.4f g/mm, intercept = %.4f g\n\n', ...
    n_fit, p_lin(1), p_lin(2));
for i = 1:n_E
    tag = '  (valid)';
    if i > n_valid, tag = '  (extrapolated)'; end
    fprintf('  E%-2d (%3.0f%% strain, w=%.3f mm): %9.2f kPa%s\n', ...
        i, strain_targets(i)*100, w_all(i), E_kPa(i), tag);
end