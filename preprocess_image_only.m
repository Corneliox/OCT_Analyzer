function [I_proc, meta] = preprocess_image_only(I_in, opts)
%PREPROCESS_IMAGE_ONLY  Denoise + bottom crop. No surface detection.
%
%   [I_proc, meta] = preprocess_image_only(I_in, opts)
%
%   Inputs:
%     I_in  - Filename (jpg/png) OR 2D grayscale matrix OR 3D RGB matrix.
%     opts  - (optional) struct:
%               bottom_crop_frac  fraction of image kept from top  (0.50)
%               median_size       median filter kernel             ([3 3])
%
%   Outputs:
%     I_proc  - Cropped grayscale image. Double in [0,1].
%     meta    - struct with .original_size, .processed_size, .opts

    if nargin < 2, opts = struct(); end
    if ~isfield(opts, 'bottom_crop_frac'), opts.bottom_crop_frac = 0.50; end
    if ~isfield(opts, 'median_size'),      opts.median_size      = [3 3]; end

    % --- Load image ---
    if ischar(I_in) || (isstring(I_in) && isscalar(I_in))
        raw = imread(char(I_in));
    else
        raw = I_in;
    end

    % Grayscale: red channel dominates the warm OCT colormap
    if ndims(raw) == 3
        I = im2double(raw(:, :, 1));
    else
        I = im2double(raw);
    end

    [H_orig, W] = size(I);

    % --- Denoise ---
    I_dn = medfilt2(I, opts.median_size, 'symmetric');

    % --- Bottom crop ---
    H_crop = round(H_orig * opts.bottom_crop_frac);
    I_proc = I_dn(1:H_crop, :);

    meta = struct();
    meta.original_size    = [H_orig, W];
    meta.processed_size   = size(I_proc);
    meta.bottom_crop_frac = opts.bottom_crop_frac;
    meta.opts             = opts;
end