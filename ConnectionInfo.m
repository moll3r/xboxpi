classdef ConnectionInfo < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        Button                  matlab.ui.control.Button
        PASSWORDEditField       matlab.ui.control.EditField
        PASSWORDEditFieldLabel  matlab.ui.control.Label
        USERNAMEEditField       matlab.ui.control.EditField
        USERNAMEEditFieldLabel  matlab.ui.control.Label
        HOSTNAMEEditField       matlab.ui.control.EditField
        HOSTNAMEEditFieldLabel  matlab.ui.control.Label
    end

    
    properties (Access = public)
        Main;
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, Main)
            app.Main = Main;
            app.HOSTNAMEEditField.Value = app.Main.ConfigData.Hostname;
            app.USERNAMEEditField.Value = app.Main.ConfigData.Username;
            app.PASSWORDEditField.Value = app.Main.ConfigData.Password;
        end

        % Button pushed function: Button
        function ButtonPushed(app, event)
            % Update config data from UI elements or other sources
            app.Main.ConfigData.Hostname = app.HOSTNAMEEditField.Value;
            app.Main.ConfigData.Username = app.USERNAMEEditField.Value;
            app.Main.ConfigData.Password = app.PASSWORDEditField.Value;
            % Save updated configuration
            app.Main.saveConfig('config.txt', app.Main.ConfigData);
            app.Main.appendToLog('Updated Connection Info');
            close(app.UIFigure);
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Get the file path for locating images
            pathToMLAPP = fileparts(mfilename('fullpath'));

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 400 128];
            app.UIFigure.Resize = 'off';

            % Create HOSTNAMEEditFieldLabel
            app.HOSTNAMEEditFieldLabel = uilabel(app.UIFigure);
            app.HOSTNAMEEditFieldLabel.HorizontalAlignment = 'center';
            app.HOSTNAMEEditFieldLabel.FontSize = 14;
            app.HOSTNAMEEditFieldLabel.FontWeight = 'bold';
            app.HOSTNAMEEditFieldLabel.Position = [22 86 85 22];
            app.HOSTNAMEEditFieldLabel.Text = 'HOSTNAME';

            % Create HOSTNAMEEditField
            app.HOSTNAMEEditField = uieditfield(app.UIFigure, 'text');
            app.HOSTNAMEEditField.Position = [115 85 185 25];

            % Create USERNAMEEditFieldLabel
            app.USERNAMEEditFieldLabel = uilabel(app.UIFigure);
            app.USERNAMEEditFieldLabel.HorizontalAlignment = 'center';
            app.USERNAMEEditFieldLabel.FontSize = 14;
            app.USERNAMEEditFieldLabel.FontWeight = 'bold';
            app.USERNAMEEditFieldLabel.Position = [22 51 85 22];
            app.USERNAMEEditFieldLabel.Text = 'USERNAME';

            % Create USERNAMEEditField
            app.USERNAMEEditField = uieditfield(app.UIFigure, 'text');
            app.USERNAMEEditField.Position = [115 50 185 25];

            % Create PASSWORDEditFieldLabel
            app.PASSWORDEditFieldLabel = uilabel(app.UIFigure);
            app.PASSWORDEditFieldLabel.HorizontalAlignment = 'center';
            app.PASSWORDEditFieldLabel.FontSize = 14;
            app.PASSWORDEditFieldLabel.FontWeight = 'bold';
            app.PASSWORDEditFieldLabel.Position = [22 17 86 22];
            app.PASSWORDEditFieldLabel.Text = 'PASSWORD';

            % Create PASSWORDEditField
            app.PASSWORDEditField = uieditfield(app.UIFigure, 'text');
            app.PASSWORDEditField.Position = [115 16 185 25];

            % Create Button
            app.Button = uibutton(app.UIFigure, 'push');
            app.Button.ButtonPushedFcn = createCallbackFcn(app, @ButtonPushed, true);
            app.Button.Tag = 'Save';
            app.Button.Icon = fullfile(pathToMLAPP, 'img', 'arrow.png');
            app.Button.BackgroundColor = [0.902 0.902 0.902];
            app.Button.FontColor = [0.902 0.902 0.902];
            app.Button.Position = [339 42 42 40];
            app.Button.Text = '';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ConnectionInfo(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end