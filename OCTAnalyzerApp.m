classdef OCTAnalyzerApp < matlab.apps.AppBase
% OCTAnalyzerApp - GUI for OCT skin layer segmentation + analysis pipeline.
% Pick the TOP folder; it recursively finds and analyzes every scan
% underneath (via batch_analyze_tree), skipping ones already done.

    properties (Access = public)
        UIFigure          matlab.ui.Figure
        TitleLabel        matlab.ui.control.Label
        FolderLabel       matlab.ui.control.Label
        FolderEdit        matlab.ui.control.EditField
        BrowseButton      matlab.ui.control.Button
        RunButton         matlab.ui.control.Button
        StatusLabel       matlab.ui.control.Label
        ProgressArea      matlab.ui.control.TextArea
        QCSamplesLabel    matlab.ui.control.Label
        QCSamplesSpinner  matlab.ui.control.Spinner
        PxPerMmLabel      matlab.ui.control.Label
        PxPerMmEdit       matlab.ui.control.NumericEditField
        OpenResultsButton matlab.ui.control.Button
    end

    properties (Access = private)
        ResultsFolder = ''
        LogLines      = {}    % internal log buffer
        % Color palette (forced light theme)
        BG     = [0.96 0.96 0.98]
        PANEL  = [1.00 1.00 1.00]
        TEXT   = [0.10 0.10 0.15]
        MUTED  = [0.35 0.35 0.45]
        ACCENT = [0.20 0.55 0.85]
        OK     = [0.15 0.55 0.25]
        ERR    = [0.75 0.15 0.15]
        WARN   = [0.85 0.55 0.05]
    end

    methods (Access = private)

        function startupFcn(app)
            app.UIFigure.Name = 'OCT Skin Layer Analyzer';
            app.log('Ready. Pick the TOP folder that holds all your data.');
            app.log('It finds and analyzes every scan underneath, skipping ones already done.');
        end

        function browseFolder(app, ~, ~)
            d = uigetdir('', 'Select the TOP folder containing all subjects/scans');
            if d ~= 0
                app.FolderEdit.Value = d;
                figure(app.UIFigure);
            end
        end

        function clearLog(app)
            app.LogLines = {};
            app.ProgressArea.Value = {''};   % must be cellstr w/ at least one element
        end

        function runPipeline(app, ~, ~)
            folder = app.FolderEdit.Value;
            if isempty(folder) || ~isfolder(folder)
                uialert(app.UIFigure, 'Please select a valid folder first.', 'No folder');
                return;
            end

            app.RunButton.Enable = 'off';
            app.BrowseButton.Enable = 'off';
            app.StatusLabel.Text = 'Status: Running...';
            app.StatusLabel.FontColor = app.WARN;
            app.OpenResultsButton.Enable = 'off';
            app.clearLog();

            try
                cleanup_obj = onCleanup(@() app.unlockUI()); %#ok<NASGU>

                app.log(sprintf('Top folder: %s', folder));
                app.log('Finding all conditions underneath and analyzing the ones not yet done.');
                app.log(' ');
                app.log('NOTE: a large run can take hours. The window may show');
                app.log('"Not Responding" while it works - that is NORMAL. Do not close it.');
                app.log('Live progress is written to batch_log.txt and batch_summary.csv');
                app.log('in the top folder - open those to watch it run.');
                app.log(' ');

                px_per_mm = app.PxPerMmEdit.Value;
                t_start = tic;
                batch_analyze_tree(folder, 'PxPerMm', px_per_mm);
                elapsed = toc(t_start);

                app.log(' ');
                app.log(sprintf('Batch finished in %.1f minutes.', elapsed/60));

                folder_clean = regexprep(folder, '[\\/]+$', '');
                app.ResultsFolder = folder_clean;   % root holds batch_summary.csv
                app.OpenResultsButton.Enable = 'on';

                % --- Tally from the summary CSV ----------------------------
                summary_csv = fullfile(folder_clean, 'batch_summary.csv');
                [n_ok, n_fail, n_skip, first_ok] = app.read_summary(summary_csv);
                app.log(sprintf('Processed: %d   Skipped(done): %d   Failed: %d', ...
                    n_ok, n_skip, n_fail));
                if n_fail > 0
                    app.log('Some conditions failed - see the "error" column in batch_summary.csv.');
                end

                % --- Visual QC on the first freshly-processed condition ----
                if ~isempty(first_ok)
                    scan = app.first_scan_subfolder(first_ok);
                    if ~isempty(scan)
                        app.log(sprintf('Showing QC grid for: %s', first_ok));
                        try
                            check_segmentation(scan, app.QCSamplesSpinner.Value);
                        catch ME
                            app.log(sprintf('QC grid skipped: %s', ME.message));
                        end
                    end
                else
                    app.log('Nothing new was processed (all already done) - no QC grid to show.');
                end

                app.StatusLabel.Text = 'Status: Done';
                app.StatusLabel.FontColor = app.OK;

            catch ME
                app.log(sprintf('ERROR: %s', ME.message));
                for k = 1:numel(ME.stack)
                    app.log(sprintf('  at %s line %d', ME.stack(k).name, ME.stack(k).line));
                end
                app.StatusLabel.Text = 'Status: Error';
                app.StatusLabel.FontColor = app.ERR;
            end
        end

        function [n_ok, n_fail, n_skip, first_ok] = read_summary(~, csv_path)
            n_ok = 0; n_fail = 0; n_skip = 0; first_ok = '';
            if ~exist(csv_path, 'file'); return; end
            try
                T = readtable(csv_path, 'TextType', 'string');
                s = T.status;
                n_ok   = sum(s == "ok");
                n_fail = sum(s == "failed");
                n_skip = sum(startsWith(s, "skipped"));
                idx = find(s == "ok", 1);
                if ~isempty(idx); first_ok = char(T.condition(idx)); end
            catch
                % malformed/locked csv - leave counts at 0, skip QC
            end
        end

        function scan = first_scan_subfolder(~, condition_folder)
            % First _N scan subfolder (lowest index) inside a condition.
            scan = '';
            if ~isfolder(condition_folder); return; end
            d = dir(condition_folder);
            d = d([d.isdir] & ~ismember({d.name}, {'.','..'}));
            d = d(~endsWith({d.name}, '_out', 'IgnoreCase', true));
            best_idx = inf;
            for i = 1:numel(d)
                tok = regexp(d(i).name, '_(\d+)(?:\.[^.]+)?$', 'tokens', 'once');
                if ~isempty(tok)
                    idx = str2double(tok{1});
                    if idx < best_idx
                        best_idx = idx;
                        scan = fullfile(condition_folder, d(i).name);
                    end
                end
            end
        end

        function unlockUI(app)
            app.RunButton.Enable = 'on';
            app.BrowseButton.Enable = 'on';
        end

        function openResults(app, ~, ~)
            if isempty(app.ResultsFolder) || ~isfolder(app.ResultsFolder)
                uialert(app.UIFigure, 'No results folder available yet.', 'Open results');
                return;
            end
            if ispc
                winopen(app.ResultsFolder);
            elseif ismac
                system(['open "', app.ResultsFolder, '"']);
            else
                system(['xdg-open "', app.ResultsFolder, '"']);
            end
        end

        function log(app, msg)
            % Append a line. Always show non-empty content (replace '' with ' ').
            if isempty(msg); msg = ' '; end
            app.LogLines{end+1} = msg;
            app.ProgressArea.Value = app.LogLines;
            try
                scroll(app.ProgressArea, 'bottom');
            catch
                % older MATLAB doesn't support scroll on textarea
            end
            drawnow;
        end
    end

    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [200 200 740 560];
            app.UIFigure.Name = 'OCT Skin Layer Analyzer';
            app.UIFigure.Color = app.BG;

            app.TitleLabel = uilabel(app.UIFigure);
            app.TitleLabel.Position = [20 510 700 32];
            app.TitleLabel.Text = 'OCT Skin Layer Analyzer';
            app.TitleLabel.FontSize = 20;
            app.TitleLabel.FontWeight = 'bold';
            app.TitleLabel.HorizontalAlignment = 'center';
            app.TitleLabel.FontColor = app.TEXT;

            app.FolderLabel = uilabel(app.UIFigure);
            app.FolderLabel.Position = [20 470 100 22];
            app.FolderLabel.Text = 'Top folder:';
            app.FolderLabel.FontWeight = 'bold';
            app.FolderLabel.FontColor = app.TEXT;

            app.FolderEdit = uieditfield(app.UIFigure, 'text');
            app.FolderEdit.Position = [120 470 490 24];
            app.FolderEdit.Placeholder = 'Select the TOP folder - it finds every scan underneath...';
            app.FolderEdit.BackgroundColor = app.PANEL;
            app.FolderEdit.FontColor = app.TEXT;

            app.BrowseButton = uibutton(app.UIFigure, 'push');
            app.BrowseButton.Position = [620 470 100 24];
            app.BrowseButton.Text = 'Browse...';
            app.BrowseButton.BackgroundColor = app.PANEL;
            app.BrowseButton.FontColor = app.TEXT;
            app.BrowseButton.ButtonPushedFcn = @(src,evt) app.browseFolder(src,evt);

            app.PxPerMmLabel = uilabel(app.UIFigure);
            app.PxPerMmLabel.Position = [20 425 110 22];
            app.PxPerMmLabel.Text = 'Pixels per mm:';
            app.PxPerMmLabel.FontColor = app.TEXT;

            app.PxPerMmEdit = uieditfield(app.UIFigure, 'numeric');
            app.PxPerMmEdit.Position = [130 425 90 24];
            app.PxPerMmEdit.Value = 200;
            app.PxPerMmEdit.Limits = [1 10000];
            app.PxPerMmEdit.BackgroundColor = app.PANEL;
            app.PxPerMmEdit.FontColor = app.TEXT;

            app.QCSamplesLabel = uilabel(app.UIFigure);
            app.QCSamplesLabel.Position = [260 425 140 22];
            app.QCSamplesLabel.Text = 'QC samples to show:';
            app.QCSamplesLabel.FontColor = app.TEXT;

            app.QCSamplesSpinner = uispinner(app.UIFigure);
            app.QCSamplesSpinner.Position = [400 425 90 24];
            app.QCSamplesSpinner.Value = 20;
            app.QCSamplesSpinner.Limits = [4 50];
            app.QCSamplesSpinner.Step = 1;
            app.QCSamplesSpinner.BackgroundColor = app.PANEL;
            app.QCSamplesSpinner.FontColor = app.TEXT;

            app.RunButton = uibutton(app.UIFigure, 'push');
            app.RunButton.Position = [20 370 220 40];
            app.RunButton.Text = 'Run batch analysis';
            app.RunButton.FontSize = 14;
            app.RunButton.FontWeight = 'bold';
            app.RunButton.BackgroundColor = app.ACCENT;
            app.RunButton.FontColor = [1 1 1];
            app.RunButton.ButtonPushedFcn = @(src,evt) app.runPipeline(src,evt);

            app.OpenResultsButton = uibutton(app.UIFigure, 'push');
            app.OpenResultsButton.Position = [260 370 200 40];
            app.OpenResultsButton.Text = 'Open results folder';
            app.OpenResultsButton.Enable = 'off';
            app.OpenResultsButton.BackgroundColor = app.PANEL;
            app.OpenResultsButton.FontColor = app.TEXT;
            app.OpenResultsButton.ButtonPushedFcn = @(src,evt) app.openResults(src,evt);

            app.StatusLabel = uilabel(app.UIFigure);
            app.StatusLabel.Position = [480 370 240 40];
            app.StatusLabel.Text = 'Status: Idle';
            app.StatusLabel.FontWeight = 'bold';
            app.StatusLabel.FontSize = 14;
            app.StatusLabel.FontColor = app.MUTED;
            app.StatusLabel.HorizontalAlignment = 'left';

            app.ProgressArea = uitextarea(app.UIFigure);
            app.ProgressArea.Position = [20 20 700 340];
            app.ProgressArea.Editable = 'off';
            app.ProgressArea.FontName = 'Consolas';
            app.ProgressArea.FontSize = 11;
            app.ProgressArea.BackgroundColor = app.PANEL;
            app.ProgressArea.FontColor = app.TEXT;
            app.ProgressArea.Value = {''};   % init with placeholder
        end
    end

    methods (Access = public)
        function app = OCTAnalyzerApp
            createComponents(app);
            registerApp(app, app.UIFigure);
            startupFcn(app);
            app.UIFigure.Visible = 'on';
            if nargout == 0; clear app; end
        end

        function delete(app)
            delete(app.UIFigure);
        end
    end
end