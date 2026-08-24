function net = train_unet_v2()
% TRAIN_UNET_V2
% Train vanilla U-Net depth-3 for 3-class OCT skin segmentation.
% Uses subject-level split prepared by prepare_data_v2.m.
%
% Architecture/loss/aug match v1 exactly (the proven-working config):
%   Input:        512 x 1024 grayscale
%   Network:      unet([512 1024 1], 3, EncoderDepth=3)
%   Loss:         0.5*CE(sum)/numel + 0.5*mean(1-genDice)
%   Augmentation: hflip + brightness/contrast (no rotation - categorical)
%   Optimizer:    Adam, lr=1e-4
%
% Returns trained `net` (also saved to disk).

% -------- Config ---------------------------------------------------------
split_file = 'C:\OCT\Chosen Ones\preprocessed\use\segment\dataset_split_v2.mat';
out_dir    = 'C:\OCT\Chosen Ones\preprocessed\use\segment\trained_v2';

target_size = [512, 1024];        % H x W after resize
num_classes = 3;
batch_size  = 4;                  % drop to 2 if RTX 4060 OOMs
init_lr     = 1e-4;
max_epochs  = 100;
patience    = 15;                 % early stop patience
% -------------------------------------------------------------------------

if ~exist(out_dir, 'dir'); mkdir(out_dir); end

% Reset GPU (your dev log: helps prevent OOM)
try; gpuDevice(1); catch; end

% --- Load split --------------------------------------------------------
S = load(split_file);
train = S.train; val = S.val;
classNames = S.classNames;
labelIDs   = S.labelIDs;

fprintf('Train: %d images   Val: %d images\n', numel(train.img), numel(val.img));

% --- Datastores --------------------------------------------------------
imdsTrain = imageDatastore(train.img);
pxdsTrain = pixelLabelDatastore(train.lbl, classNames, labelIDs);
imdsVal   = imageDatastore(val.img);
pxdsVal   = pixelLabelDatastore(val.lbl, classNames, labelIDs);

dsTrain = combine(imdsTrain, pxdsTrain);
dsVal   = combine(imdsVal,   pxdsVal);

% Closure pattern (v1 lesson: classNames isn't visible inside local fn)
dsTrain = transform(dsTrain, @(d) augment_resize(d, classNames, target_size, true));
dsVal   = transform(dsVal,   @(d) augment_resize(d, classNames, target_size, false));

% --- Network -----------------------------------------------------------
net = unet([target_size, 1], num_classes, EncoderDepth=3);

% --- Training options --------------------------------------------------
opts = trainingOptions("adam", ...
    InitialLearnRate=init_lr, ...
    MaxEpochs=max_epochs, ...
    MiniBatchSize=batch_size, ...
    Shuffle="every-epoch", ...
    ValidationData=dsVal, ...
    ValidationFrequency=max(1, floor(numel(train.img)/batch_size)), ...
    ValidationPatience=patience, ...
    OutputNetwork="best-validation-loss", ...
    Plots="training-progress", ...
    Verbose=true, ...
    ExecutionEnvironment="gpu");

% --- Train -------------------------------------------------------------
fprintf('\nStarting training...\n');
net = trainnet(dsTrain, net, @combined_loss, opts);

% --- Save --------------------------------------------------------------
out_path = fullfile(out_dir, sprintf('unet_v2_%s.mat', datestr(now,'yyyymmdd_HHMMSS')));
save(out_path, 'net', 'classNames', 'labelIDs', 'target_size');
fprintf('\nSaved trained network -> %s\n', out_path);
end

% =========================================================================
function loss = combined_loss(Y, T)
% v1's proven-working R2025b syntax:
%   - crossentropy 'mean' not allowed in R2025b → sum/numel manually
%   - generalizedDice DataFormat not allowed when input is formatted dlarray
%   - generalizedDice may return per-class → mean() to get scalar
ce_loss   = crossentropy(Y, T, Reduction="sum") / numel(T);
dice_loss = mean(1 - generalizedDice(Y, T));
loss = 0.5 * ce_loss + 0.5 * dice_loss;
end

% =========================================================================
function dataOut = augment_resize(data, classNames, target_size, isTraining)
% data is {image, label} from combine(imds, pxds).
% label is categorical from pixelLabelDatastore.

img = data{1};
lbl = data{2};

% Force grayscale single channel
if size(img, 3) == 3; img = rgb2gray(img); end

% --- Resize ---------------------------------------------------------
img = imresize(img, target_size, 'bilinear');
% categorical → uint8 (1-indexed) → 0-indexed → resize → categorical
lbl_u = uint8(lbl) - 1;
lbl_u = imresize(lbl_u, target_size, 'nearest');
lbl   = categorical(lbl_u, 0:numel(classNames)-1, classNames);

% --- Augmentation (training only) -----------------------------------
if isTraining
    % H-flip 50% (works on categorical, unlike imrotate)
    if rand < 0.5
        img = fliplr(img);
        lbl = fliplr(lbl);
    end
    % Brightness ±10% of full range
    img = double(img);
    img = img + (rand*0.2 - 0.1) * 255;
    % Contrast ±20%
    m = mean(img(:));
    img = (img - m) * (1 + rand*0.4 - 0.2) + m;
    img = uint8(max(0, min(255, img)));
end

dataOut = {img, lbl};
end