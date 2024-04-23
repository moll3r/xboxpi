classdef MainWindow < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                       matlab.ui.Figure
        FileMenu                       matlab.ui.container.Menu
        ConnecttoPiMenu                matlab.ui.container.Menu
        DisconnectResetMenu            matlab.ui.container.Menu
        EditMenu                       matlab.ui.container.Menu
        ConnectionInfoMenu             matlab.ui.container.Menu
        HelpMenu                       matlab.ui.container.Menu
        UpdateTempsCheckBox            matlab.ui.control.CheckBox
        PiStatusDisconnectedLamp       matlab.ui.control.Lamp
        PiStatusDisconnectedLampLabel  matlab.ui.control.Label
        ChassisTempCEditField          matlab.ui.control.NumericEditField
        ChassisTempCEditFieldLabel     matlab.ui.control.Label
        CPUTempCEditField              matlab.ui.control.NumericEditField
        CPUTempCEditFieldLabel         matlab.ui.control.Label
        TextArea                       matlab.ui.control.TextArea
        OPENButton                     matlab.ui.control.Button
        SAVEButton                     matlab.ui.control.Button
        WRITEButton                    matlab.ui.control.Button
        READButton                     matlab.ui.control.Button
        RegionSettingDropDown          matlab.ui.control.DropDown
        RegionSettingDropDownLabel     matlab.ui.control.Label
        HDDKeyEditField                matlab.ui.control.EditField
        HDDKeyEditFieldLabel           matlab.ui.control.Label
        VersionEditField               matlab.ui.control.EditField
        VersionEditFieldLabel          matlab.ui.control.Label
        XBOXSerialEditField            matlab.ui.control.EditField
        XBOXSerialLabel                matlab.ui.control.Label
    end

    properties (Access = public)
        ConfigData struct;
        xbp;
        eeprom;
        ADM1032;
        connectedStatus;
        chipData;
    end

    methods (Access = private)
        function config = loadConfig(app, filename)
            if exist(filename, 'file')
                fid = fopen(filename, 'rt');
                hostname = fgetl(fid);
                username = fgetl(fid);
                password = fgetl(fid);
                fclose(fid);
                config = struct('Hostname', hostname, 'Username', username, 'Password', password);
                appendToLog(app, 'Successfully loaded config file!');
            else
                config = struct('Hostname', '', 'Username', '', 'Password', '');
                app.saveConfig(filename, config);  % Create file with default empty config
                appendToLog(app, 'No config file found, creating one!');
                appendToLog(app, 'You probably want to edit your config in Edit -> Connection Info');
            end
        end
        function setPiConnected(app, state)
            if state
                app.appendToLog(sprintf('Raspberry Pi Connected @ %s', app.ConfigData.Hostname));
                app.connectedStatus = true;
                app.PiStatusDisconnectedLamp.Color = 'green';
                app.PiStatusDisconnectedLampLabel.Text = 'Status: Connected';
                app.WRITEButton.Enable =            'on';
                app.READButton.Enable =             'on';

            else
                if app.connectedStatus
                    app.appendToLog('Attempting to Disconnect...');
                    try
                        app.connectedStatus = false;
                        clear app.ADM1032;
                        clear app.eeprom;
                        clear app.xbp;
                    catch
                        app.appendToLog('Waiting 10 Seconds to Disconnect...');
                        pause(10);
                        clear app.ADM1032;
                        pause(0.2);
                        clear app.eeprom;
                        pause(0.2);
                        clear app.xbp
                        pause(0.2);
                    end
                end
                app.connectedStatus = false;
                app.appendToLog('Raspberry Pi Disconnected');
                app.PiStatusDisconnectedLamp.Color = 'red';
                app.PiStatusDisconnectedLampLabel.Text = 'Status: Disconnected';
                app.WRITEButton.Enable =            'off';
                app.READButton.Enable =             'off';
                app.SAVEButton.Enable =             'off';
                app.CPUTempCEditField.Enable =      'off';
                app.ChassisTempCEditField.Enable=   'off';
                app.RegionSettingDropDown.Enable=   'off';
                app.VersionEditField.Enable =       'off';
                app.HDDKeyEditField.Enable =        'off';
                app.XBOXSerialEditField.Enable =    'off';
            end
        end
        function fullData = readEEPROM(~, eepromDevice, totalBytes, maxBytesPerRead)
            fullData = [];
            while totalBytes > 0
                bytesToRead = min(totalBytes, maxBytesPerRead);
                partData = read(eepromDevice, bytesToRead, 'uint8')';
                fullData = [fullData; partData];
                totalBytes = totalBytes - bytesToRead;
            end
        end

        function EEPROM = cryptEEPROM(app, EEPROM, decrypt)
            % Version 1.0 Motherboard Key
            enc(1).key = [0x2A; 0x3B; 0xAD; 0x2C; 0xB1; 0x94; 0x4F; 0x93; 0xAA; 0xCD; 0xCD; 0x7E; 0x0A; 0xC2; 0xEE; 0x5A];
            enc(1).con = [0x00; 0x00; 0x00; 0x00; 0x10; 0xA0; 0x1C; 0x00];
            % Version 1.1-1.4 Motherboard Key
            enc(2).key = [0x1D; 0xF3; 0x5C; 0x83; 0x8E; 0xC9; 0xB6; 0xFC; 0xBD; 0xF6; 0x61; 0xAB; 0x4F; 0x06; 0x33; 0xE4];
            enc(2).con = [0x0F; 0x2A; 0x20; 0xD3; 0x49; 0x17; 0xC8; 0x6D];
            % Version 1.6+ Motherboard Key
            enc(3).key = [0x2B; 0x84; 0x57; 0xBE; 0x9B; 0x1E; 0x65; 0xC6; 0xCD; 0x9D; 0x2B; 0xCE; 0xC1; 0xA2; 0x09; 0x61];
            enc(3).con = [0x4C; 0x70; 0x33; 0xCB; 0x5B; 0xB5; 0x97; 0xD2];

            XBVersion = str2double(join(char(EEPROM(0x3B:0x3C)')));
            if XBVersion < 24
                XBOXKey = enc(1).key;
                app.VersionEditField.Value = '1.0';
            elseif XBVersion < 34
                XBOXKey = enc(2).key;
                app.VersionEditField.Value = '1.1-1.4';
            else
                XBOXKey = enc(3).key;
                app.VersionEditField.Value = '1.6+';
            end

            if decrypt
                key = HMACSHA1(EEPROM(0x01:0x14), XBOXKey);
                data = rc4(EEPROM(0x15:0x30), key);
                if HMACSHA1(data, XBOXKey) == EEPROM(0x01:0x14)
                    EEPROM(0x15:0x30) = data;
                    app.appendToLog('Sucessfully Decrypted EEPROM!');
                else
                    app.appendToLog('Error Decrypting EEPROM!');
                end
            else
                checksum = HMACSHA1(EEPROM(0x15:0x30), XBOXKey);
                key = HMACSHA1(checksum, XBOXKey);
                EEPROM(0x15:0x30) = rc4(EEPROM(0x15:0x30), key);
                EEPROM(0x01:0x14) = checksum;
                app.appendToLog('Encrypted EEPROM!');
            end

            function hmacSHA1Column = HMACSHA1(message, key)
                import java.security.*;
                import javax.crypto.*;
                import javax.crypto.spec.*;
                secretKeySpec = SecretKeySpec(key, 'HmacSHA1');
                mac = Mac.getInstance('HmacSHA1');
                mac.init(secretKeySpec);
                hmacResult = mac.doFinal(message);
                hmacSHA1Column = typecast(hmacResult, 'uint8');
            end

            function res = rc4(data, key)
                P = data';
                Z = uint8(PRGA(KSA(key), size(P,2)));
                res = bitxor(Z, P)';
                function S = KSA(key)
                    key = uint16(key)';
                    key_length = size(key,2);
                    S=0:255;
                    j=0;
                    for i=0:1:255
                        j = mod(j+S(i+1)+key(mod(i,key_length)+1),256);
                        S([i+1 j+1]) = S([j+1 i+1]);
                    end
                end
                function key = PRGA(S, n)
                    i = 0;
                    j = 0;
                    key = uint16([]);
                    while n> 0
                        n = n - 1;
                        i = mod(i+1,256);
                        j = mod(j+S(i+1),256);
                        S([i+1 j+1]) = S([j+1 i+1]);
                        K = S(mod(S(i+1)+S(j+1),256)+1);
                        key = [key, K];
                    end
                end
            end
        end
        function loadEEPROM(app)
            app.chipData = app.cryptEEPROM(app.chipData, true);
            app.HDDKeyEditField.Value = join(compose("%.2X", app.chipData(0x1D:0x2C)), '');
            app.XBOXSerialEditField.Value = char(app.chipData(0x35:0x40)');
            switch uint8(app.chipData(0x2D))
                case 1
                    app.RegionSettingDropDown.Value = "North America";
                case 2
                    app.RegionSettingDropDown.Value = "Japan";
                case 4
                    app.RegionSettingDropDown.Value = "Europe/Australia";
                otherwise
                    app.RegionSettingDropDown.Value = "";
                    app.appendToLog("Found Unknown Country! Code: "+string(uint8(app.chipData(0x2D))));
            end
            app.appendToLog('Successfully Read EEPROM Data!');
            if app.connectedStatus
                app.UpdateTempsCheckBoxValueChanged();
            end
        end
        function initiateEEPROM(app)
            try
                app.eeprom = i2cdev(app.xbp, 'i2c-1', '0x54');
            catch ME
                switch ME.identifier
                    case 'MATLAB:hwsdk:general:conflictI2CAddress'
                        app.appendToLog('Already Connected to EEPROM Chip... Continuing...')
                    otherwise
                        app.appendToLog('An unexpected error occurred while trying to connect to the I2C Bus.');
                        app.setPiConnected(false);
                        app.appendToLog(sprintf('Error Identifier: %s\n', ME.identifier));
                        app.appendToLog(sprintf('Error Message: %s\n', ME.message));
                        return
                end
            end
            app.CPUTempCEditField.Enable =      'on';
            app.ChassisTempCEditField.Enable=   'on';
            app.RegionSettingDropDown.Enable=   'on';
            app.VersionEditField.Enable =       'on';
            app.HDDKeyEditField.Enable =        'on';
            app.XBOXSerialEditField.Enable =    'on';
            app.SAVEButton.Enable =             'on';
            app.UpdateTempsCheckBox.Value =     true;
        end
    end


    methods (Access = public)
        function saveConfig(~, filename, config)
            fid = fopen(filename, 'wt');
            fprintf(fid, '%s\n', config.Hostname);
            fprintf(fid, '%s\n', config.Username);
            fprintf(fid, '%s\n', config.Password);
            fclose(fid);
        end
        function appendToLog(app, newText)
            % Generate timestamp
            dt = datetime('now', 'Format', '[HH:mm:ss]');
            timestamp = char(dt); % Convert datetime object to character array for display

            % Combine timestamp with new text
            newTextWithTimestamp = sprintf('%s %s', timestamp, newText);

            % Check the current state of the TextArea and handle accordingly
            if isempty(app.TextArea.Value) || isequal(app.TextArea.Value, "")
                % If the TextArea is empty or contains only an empty string
                app.TextArea.Value = newTextWithTimestamp; % Initialize directly with newTextWithTimestamp
            else
                % If TextArea already contains text, ensure it's in cell array form
                if ischar(app.TextArea.Value)
                    % Convert from char array to cell array if it's a single line of text
                    currentText = {app.TextArea.Value};
                elseif isstring(app.TextArea.Value) && isscalar(app.TextArea.Value)
                    % Handle single scalar string (unlikely but good for completeness)
                    currentText = {char(app.TextArea.Value)};
                else
                    % Assume it's already a cell array of chars
                    currentText = app.TextArea.Value;
                end

                % Append new text as a new cell element
                app.TextArea.Value = [currentText; newTextWithTimestamp];
            end

            % Scroll to the bottom of the TextArea
            drawnow; % Make sure GUI is updated
            app.TextArea.scroll('bottom');
        end
    end


    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            app.ConfigData = loadConfig(app, 'config.txt');
            app.setPiConnected(false);
        end

        % Menu selected function: ConnectionInfoMenu
        function ConnectionInfoMenuSelected(app, event)
            connectionInfo = ConnectionInfo(app);
            % Get Parent App's position and size
            parentPosition = app.UIFigure.Position;
            parentWidth = parentPosition(3);
            parentHeight = parentPosition(4);
            parentX = parentPosition(1);
            parentY = parentPosition(2);

            childWidth = 400; % Example width of child window
            childHeight = 128; % Example height of child window

            % Calculate the new position for the child window
            newX = parentX + (parentWidth - childWidth) / 2;
            newY = parentY + (parentHeight - childHeight) / 2;

            % Set the position of the ChildApp window
            connectionInfo.UIFigure.Position = [newX, newY, childWidth, childHeight];
        end

        % Menu selected function: DisconnectResetMenu
        function DisconnectResetMenuSelected(app, event)
            app.setPiConnected(false);
        end

        % Menu selected function: ConnecttoPiMenu
        function ConnecttoPiMenuSelected(app, event)
            if ~app.connectedStatus
                try
                    app.appendToLog('Connecting to Raspberry Pi...');
                    app.xbp = raspi(app.ConfigData.Hostname, app.ConfigData.Username, app.ConfigData.Password);
                    app.setPiConnected(true);
                catch ME
                    switch ME.identifier
                        case 'MATLAB:hwsdk:general:connectionExists'
                            app.appendToLog('Raspberry Pi Already Connected!');
                            app.setPiConnected(true);
                        case 'raspi:utils:InvalidCredential'
                            app.appendToLog('Failed to connect to the Raspberry Pi: Authentication Failure.');
                            app.appendToLog(sprintf('Error Message: %s\n', ME.message));
                            app.setPiConnected(false);
                        otherwise
                            app.appendToLog('An unexpected error occurred while trying to connect to the Raspberry Pi.');
                            app.appendToLog(sprintf('Error Identifier: %s\n', ME.identifier));
                            app.appendToLog(sprintf('Error Message: %s\n', ME.message));
                            app.setPiConnected(false);
                    end
                end
            end
        end

        % Value changed function: UpdateTempsCheckBox
        function UpdateTempsCheckBoxValueChanged(app, event)
            while app.UpdateTempsCheckBox.Value && app.connectedStatus
                try
                    app.ADM1032 = i2cdev(app.xbp, 'i2c-1', '0x4C');
                    app.appendToLog('Successfully Connected to SMC!');
                catch ME
                    switch ME.identifier
                        case 'MATLAB:hwsdk:general:conflictI2CAddress'
                            tempData = read(app.ADM1032, 2, 'uint8');
                            tempData(2) = (tempData(2)-32)*(5/9);
                            app.CPUTempCEditField.Value = double(tempData(2));
                            app.ChassisTempCEditField.Value = double(tempData(1));
                            app.appendToLog('Updated Live Temperature Data!');
                            pause(10);
                        otherwise
                            app.appendToLog('An unexpected error occurred while trying to connect to the SMC Module.');
                            app.appendToLog(sprintf('Error Identifier: %s\n', ME.identifier));
                            app.appendToLog(sprintf('Error Message: %s\n', ME.message));
                            app.setPiConnected(false);
                            break;
                    end
                end
            end
        end

        % Button pushed function: WRITEButton
        function WRITEButtonPushed(app, event)
            app.appendToLog("Initiating Write Sequence...");
            app.initiateEEPROM();
            writeData = app.cryptEEPROM(app.chipData, false);
            if app.connectedStatus && app.readEEPROM(app.eeprom, 256, 128) == writeData
                app.appendToLog('EEPROM is already up-to-date!');
            elseif app.connectedStatus
                for i=1:length(writeData)
                    writeRegister(app.eeprom, i-1, writeData(i), 'uint8');
                    if mod(i,16)==0
                        app.appendToLog('Written '+string(round(i/length(writeData)*100))+'%');
                    end
                    read(app.eeprom, 1); % Glitchy offset fix
                    if app.readEEPROM(app.eeprom, 256, 128) == writeData
                        app.appendToLog('Sucessfully Written EEPROM!');
                    end
                end
            end
        end

        % Button pushed function: READButton
        function READButtonPushed(app, event)
            app.appendToLog("Attempting EEPROM Read...");
            app.initiateEEPROM();
            if app.connectedStatus
                app.chipData = app.readEEPROM(app.eeprom, 256, 128);
                app.loadEEPROM();
            else
                app.appendToLog("Read Failed!");
            end
        end

        % Button pushed function: SAVEButton
        function SAVEButtonPushed(app, event)
            [file,location] = uiputfile(app.XBOXSerialEditField.Value+".bin");
            if ~isequal(file,0) || ~isequal(location,0)
                save = fopen(fullfile(location,file), "w");
                fwrite(save,app.cryptEEPROM(app.chipData, false));
                app.appendToLog("Saved EEPROM to "+file);
                fclose(save);
            end
        end

        % Button pushed function: OPENButton
        function OPENButtonPushed(app, event)
            [file,location] = uigetfile("*.bin");
            if ~isequal(file,0)
                save = fopen(fullfile(location,file), "r");
                app.chipData = uint8(fread(save));
                app.loadEEPROM();
                app.RegionSettingDropDown.Enable=   'on';
                app.VersionEditField.Enable =       'on';
                app.HDDKeyEditField.Enable =        'on';
                app.XBOXSerialEditField.Enable =    'on';
                app.SAVEButton.Enable =             'on';
                app.appendToLog("Loaded EEPROM from "+file);
                fclose(save);
            end
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            app.setPiConnected(false);
            delete(app);
        end

        % Value changed function: XBOXSerialEditField
        function XBOXSerialEditFieldValueChanged(app, event)
            value = app.XBOXSerialEditField.Value;
            if length(value) == 12
                app.chipData(0x35:0x40) = uint8(value)';
            else
                app.XBOXSerialEditField.Value = char(app.chipData(0x35:0x40)');
            end
        end

        % Value changed function: HDDKeyEditField
        function HDDKeyEditFieldValueChanged(app, event)
            value = app.HDDKeyEditField.Value;
            if length(value) == 32 & regexp(value, '^[0-9A-Fa-f]+$', 'once')
                app.chipData(0x1D:0x2C) = uint8(hex2dec(regexp(value, '.{2}', 'match')));
            end
            app.HDDKeyEditField.Value = join(compose("%.2X", app.chipData(0x1D:0x2C)), '');
        end

        % Value changed function: RegionSettingDropDown
        function RegionSettingDropDownValueChanged(app, event)
            value = app.RegionSettingDropDown.Value;
            switch value
                case "North America"
                    app.chipData(0x2D) = uint8(1);
                case "Japan"
                    app.chipData(0x2D) = uint8(2);
                case "Europe/Australia"
                    app.chipData(0x2D) = uint8(4);
                otherwise
                    app.chipData(0x2D) = uint8(1);
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Position = [100 100 500 478];
            app.UIFigure.Name = 'MATLAB App';
            app.UIFigure.Resize = 'off';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Create FileMenu
            app.FileMenu = uimenu(app.UIFigure);
            app.FileMenu.Text = 'File';

            % Create ConnecttoPiMenu
            app.ConnecttoPiMenu = uimenu(app.FileMenu);
            app.ConnecttoPiMenu.MenuSelectedFcn = createCallbackFcn(app, @ConnecttoPiMenuSelected, true);
            app.ConnecttoPiMenu.Text = 'Connect to Pi';

            % Create DisconnectResetMenu
            app.DisconnectResetMenu = uimenu(app.FileMenu);
            app.DisconnectResetMenu.MenuSelectedFcn = createCallbackFcn(app, @DisconnectResetMenuSelected, true);
            app.DisconnectResetMenu.Text = 'Disconnect/Reset';

            % Create EditMenu
            app.EditMenu = uimenu(app.UIFigure);
            app.EditMenu.Text = 'Edit';

            % Create ConnectionInfoMenu
            app.ConnectionInfoMenu = uimenu(app.EditMenu);
            app.ConnectionInfoMenu.MenuSelectedFcn = createCallbackFcn(app, @ConnectionInfoMenuSelected, true);
            app.ConnectionInfoMenu.Text = 'Connection Info';

            % Create HelpMenu
            app.HelpMenu = uimenu(app.UIFigure);
            app.HelpMenu.Text = 'Help';

            % Create XBOXSerialLabel
            app.XBOXSerialLabel = uilabel(app.UIFigure);
            app.XBOXSerialLabel.FontName = 'Consolas';
            app.XBOXSerialLabel.FontWeight = 'bold';
            app.XBOXSerialLabel.Position = [43 425 91 22];
            app.XBOXSerialLabel.Text = 'XBOX Serial #';

            % Create XBOXSerialEditField
            app.XBOXSerialEditField = uieditfield(app.UIFigure, 'text');
            app.XBOXSerialEditField.InputType = 'digits';
            app.XBOXSerialEditField.ValueChangedFcn = createCallbackFcn(app, @XBOXSerialEditFieldValueChanged, true);
            app.XBOXSerialEditField.FontName = 'Consolas';
            app.XBOXSerialEditField.Position = [42 405 100 22];

            % Create VersionEditFieldLabel
            app.VersionEditFieldLabel = uilabel(app.UIFigure);
            app.VersionEditFieldLabel.HorizontalAlignment = 'center';
            app.VersionEditFieldLabel.FontName = 'Consolas';
            app.VersionEditFieldLabel.FontWeight = 'bold';
            app.VersionEditFieldLabel.Position = [215 425 51 22];
            app.VersionEditFieldLabel.Text = 'Version';

            % Create VersionEditField
            app.VersionEditField = uieditfield(app.UIFigure, 'text');
            app.VersionEditField.Editable = 'off';
            app.VersionEditField.FontName = 'Consolas';
            app.VersionEditField.Position = [203 405 76 22];

            % Create HDDKeyEditFieldLabel
            app.HDDKeyEditFieldLabel = uilabel(app.UIFigure);
            app.HDDKeyEditFieldLabel.FontWeight = 'bold';
            app.HDDKeyEditFieldLabel.Position = [42 346 56 22];
            app.HDDKeyEditFieldLabel.Text = 'HDD Key';

            % Create HDDKeyEditField
            app.HDDKeyEditField = uieditfield(app.UIFigure, 'text');
            app.HDDKeyEditField.ValueChangedFcn = createCallbackFcn(app, @HDDKeyEditFieldValueChanged, true);
            app.HDDKeyEditField.FontName = 'Consolas';
            app.HDDKeyEditField.Position = [42 325 237 22];

            % Create RegionSettingDropDownLabel
            app.RegionSettingDropDownLabel = uilabel(app.UIFigure);
            app.RegionSettingDropDownLabel.FontWeight = 'bold';
            app.RegionSettingDropDownLabel.Position = [43 276 90 22];
            app.RegionSettingDropDownLabel.Text = 'Region Setting';

            % Create RegionSettingDropDown
            app.RegionSettingDropDown = uidropdown(app.UIFigure);
            app.RegionSettingDropDown.Items = {'', 'North America', 'Japan', 'Europe/Australia'};
            app.RegionSettingDropDown.ValueChangedFcn = createCallbackFcn(app, @RegionSettingDropDownValueChanged, true);
            app.RegionSettingDropDown.Position = [42 255 136 22];
            app.RegionSettingDropDown.Value = '';

            % Create READButton
            app.READButton = uibutton(app.UIFigure, 'push');
            app.READButton.ButtonPushedFcn = createCallbackFcn(app, @READButtonPushed, true);
            app.READButton.Position = [61 183 78 23];
            app.READButton.Text = 'READ';

            % Create WRITEButton
            app.WRITEButton = uibutton(app.UIFigure, 'push');
            app.WRITEButton.ButtonPushedFcn = createCallbackFcn(app, @WRITEButtonPushed, true);
            app.WRITEButton.Position = [161 183 78 23];
            app.WRITEButton.Text = 'WRITE';

            % Create SAVEButton
            app.SAVEButton = uibutton(app.UIFigure, 'push');
            app.SAVEButton.ButtonPushedFcn = createCallbackFcn(app, @SAVEButtonPushed, true);
            app.SAVEButton.Position = [261 183 78 23];
            app.SAVEButton.Text = 'SAVE';

            % Create OPENButton
            app.OPENButton = uibutton(app.UIFigure, 'push');
            app.OPENButton.ButtonPushedFcn = createCallbackFcn(app, @OPENButtonPushed, true);
            app.OPENButton.Position = [361 183 78 23];
            app.OPENButton.Text = 'OPEN';

            % Create TextArea
            app.TextArea = uitextarea(app.UIFigure);
            app.TextArea.Editable = 'off';
            app.TextArea.WordWrap = 'off';
            app.TextArea.FontName = 'Consolas';
            app.TextArea.FontColor = [1 1 1];
            app.TextArea.BackgroundColor = [0 0 0];
            app.TextArea.Position = [1 19 500 130];

            % Create CPUTempCEditFieldLabel
            app.CPUTempCEditFieldLabel = uilabel(app.UIFigure);
            app.CPUTempCEditFieldLabel.HorizontalAlignment = 'right';
            app.CPUTempCEditFieldLabel.FontName = 'Consolas';
            app.CPUTempCEditFieldLabel.FontWeight = 'bold';
            app.CPUTempCEditFieldLabel.Position = [365 425 84 22];
            app.CPUTempCEditFieldLabel.Text = 'CPU Temp (C)';

            % Create CPUTempCEditField
            app.CPUTempCEditField = uieditfield(app.UIFigure, 'numeric');
            app.CPUTempCEditField.AllowEmpty = 'on';
            app.CPUTempCEditField.Editable = 'off';
            app.CPUTempCEditField.HorizontalAlignment = 'center';
            app.CPUTempCEditField.FontName = 'Consolas';
            app.CPUTempCEditField.FontSize = 36;
            app.CPUTempCEditField.Placeholder = '-';
            app.CPUTempCEditField.Position = [358 381 100 46];
            app.CPUTempCEditField.Value = [];

            % Create ChassisTempCEditFieldLabel
            app.ChassisTempCEditFieldLabel = uilabel(app.UIFigure);
            app.ChassisTempCEditFieldLabel.HorizontalAlignment = 'center';
            app.ChassisTempCEditFieldLabel.FontName = 'Consolas';
            app.ChassisTempCEditFieldLabel.FontWeight = 'bold';
            app.ChassisTempCEditFieldLabel.Position = [353 332 111 22];
            app.ChassisTempCEditFieldLabel.Text = 'Chassis Temp (C)';

            % Create ChassisTempCEditField
            app.ChassisTempCEditField = uieditfield(app.UIFigure, 'numeric');
            app.ChassisTempCEditField.AllowEmpty = 'on';
            app.ChassisTempCEditField.Editable = 'off';
            app.ChassisTempCEditField.HorizontalAlignment = 'center';
            app.ChassisTempCEditField.FontName = 'Consolas';
            app.ChassisTempCEditField.FontSize = 36;
            app.ChassisTempCEditField.Placeholder = '-';
            app.ChassisTempCEditField.Position = [358 287 100 46];
            app.ChassisTempCEditField.Value = [];

            % Create PiStatusDisconnectedLampLabel
            app.PiStatusDisconnectedLampLabel = uilabel(app.UIFigure);
            app.PiStatusDisconnectedLampLabel.HorizontalAlignment = 'right';
            app.PiStatusDisconnectedLampLabel.FontSize = 10;
            app.PiStatusDisconnectedLampLabel.Position = [373 -3 111 22];
            app.PiStatusDisconnectedLampLabel.Text = 'Pi Status: Disconnected';

            % Create PiStatusDisconnectedLamp
            app.PiStatusDisconnectedLamp = uilamp(app.UIFigure);
            app.PiStatusDisconnectedLamp.Position = [487 4 10 10];
            app.PiStatusDisconnectedLamp.Color = [1 0 0];

            % Create UpdateTempsCheckBox
            app.UpdateTempsCheckBox = uicheckbox(app.UIFigure);
            app.UpdateTempsCheckBox.ValueChangedFcn = createCallbackFcn(app, @UpdateTempsCheckBoxValueChanged, true);
            app.UpdateTempsCheckBox.Text = 'Update Temps';
            app.UpdateTempsCheckBox.FontWeight = 'bold';
            app.UpdateTempsCheckBox.Position = [358 247 104 22];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = MainWindow

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.UIFigure)

                % Execute the startup function
                runStartupFcn(app, @startupFcn)
            else

                % Focus the running singleton app
                figure(runningApp.UIFigure)

                app = runningApp;
            end

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