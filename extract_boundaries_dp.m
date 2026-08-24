function [top_sc, bot_sc, end_ed] = extract_boundaries_dp(prob_map, lambda, max_jump)
% EXTRACT_BOUNDARIES_DP
% Recover smooth top-of-SC, bottom-of-SC, end-of-ED boundary curves from
% U-Net softmax probability maps via dynamic programming.
% Vectorized for speed.

if nargin < 2 || isempty(lambda);   lambda   = 0.1; end
if nargin < 3 || isempty(max_jump); max_jump = 5;   end

P_bg = prob_map(:,:,1);
P_sc = prob_map(:,:,2);
P_ed = prob_map(:,:,3);

shift_down = @(X) [zeros(1, size(X,2)); X(1:end-1, :)];
eps = 1e-6;

P_skin = P_sc + P_ed;
cost_top = -log(shift_down(P_bg) + eps) - log(P_skin + eps);
cost_bot = -log(shift_down(P_sc) + eps) - log(P_ed + eps);
cost_end = -log(shift_down(P_ed) + eps) - log(P_bg + eps);

top_sc = dp_path(cost_top, lambda, max_jump);
bot_sc = dp_path(cost_bot, lambda, max_jump);
end_ed = dp_path(cost_end, lambda, max_jump);

bot_sc = max(bot_sc, top_sc);
end_ed = max(end_ed, bot_sc);
end

% =========================================================================
function path = dp_path(cost, lambda, max_jump)
% Find minimum-cost smooth path through a cost map (H x W).
% Vectorized over rows.
[H, W] = size(cost);
M = inf(H, W);
B = zeros(H, W, 'int32');

M(:, 1) = cost(:, 1);

jumps = -max_jump : max_jump;
penalties = lambda * (jumps .^ 2);
candidates = zeros(H, length(jumps));

for c = 2:W
    prev = M(:, c-1);
    P = [inf(max_jump, 1); prev; inf(max_jump, 1)];
    
    for k = 1:length(jumps)
        shift_j = jumps(k);
        candidates(:, k) = P(max_jump + 1 + shift_j : max_jump + H + shift_j) + penalties(k);
    end
    
    [best_costs, best_k] = min(candidates, [], 2);
    M(:, c) = cost(:, c) + best_costs;
    B(:, c) = int32((1:H)' + jumps(best_k)');
end

path = zeros(1, W);
[~, last] = min(M(:, W));
path(W) = last;
for c = W-1:-1:1
    path(c) = double(B(path(c+1), c+1));
end
end