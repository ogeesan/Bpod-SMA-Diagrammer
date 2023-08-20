function [mermaid_text, human_sma] = sma_diagram(sma, varargin)
% [mermaid_text, human_sma] = sma_diagram(sma, ...)
% Construct a human-readable way of understanding a state matrix
%
% Parameters
% ----------
% sma : struct
%   The state matrix constructed using NewStateMachine/AddState()
% display: bool, default true
%   Print result in the Command Window
% createfile : bool, default false
%   Create a mermaid structured schematic in a .md file and save to filepath
% filepath : str, default 'sma_diagram_output.md'
%   Path to generate the .md file
% codewrap : bool, default true
%   Wrap the mermaid code in ```mermaid for embedding in markdown.
%
% Returns
% -------
% mermaid_text : char
%   The code required to build a diagram in mermaid
% human_sma : struct
%   State matrix in a human-readable format

%{
Mermaid usage guide
Mermaid is a diagram/charting tool (https://mermaid.js.org/)
It's usage (for me at least) is embedding diagrams in Markdown, as it's
used by a lot of Markdown editors (Github, Obsidian, Typora). It's text
instructions for building diagarms, and this tool creates those
instructions using the state machine assembler from Bpod.

With the text that gets printed into the Command Window you can copy/paste
it into mermaid.live to see what your state matrix looks like, or paste it
into a markdown editor.

In order to construct a state matrix you'll have to run Bpod (at least in
emulator mode) because AddState() interfaces with the BpodSystem object.

GS August 2023

%}

% Create mermaid state diagram from state machine
p = inputParser();
p.addParameter('createfile', false)
p.addParameter('display', true)
p.addParameter('filepath', [])
p.addParameter('codewrap', true)
p.addParameter('timerprecision', '%.3f')
p.addParameter('showoutputactions', true)
p.parse(varargin{:})

global BpodSystem

state_time_transition_sprintf = ['\t%s --> %s: Tup (' p.Results.timerprecision ') \n'];

human_sma = struct;
current_state_number = 0;
mermaid_text = 'stateDiagram-v2\n';
hyphen_check = false;
for StateCell = sma.StateNames
    statename = StateCell{1};
    hyphen_check = sum(statename == '-') > 0 | hyphen_check;
    statename = fix_statename(statename);
    current_state_number = current_state_number + 1;

    state_human_sma = struct;
    state_human_sma.Tup = [];
    state_human_sma.OutputActions = struct;
    state_human_sma.StateChangeConditions = struct;
    
    % -- Create State's info line (i.e. output actions)
    stateDetails = sprintf('%s: %s', statename, statename);
    % Extract output actions from the OutputMatrix
    outputActionsForRow = sma.OutputMatrix(current_state_number, :);
    actionDetails = '';  % Initialize an empty string for action details
    for col = 1:length(outputActionsForRow)
        if outputActionsForRow(col) ~= 0  % Assuming 0 means no action
            actionName = BpodSystem.StateMachineInfo.OutputChannelNames{col};
            actionValue = outputActionsForRow(col);
            actionDetails = [actionDetails '\\n' sprintf('%s %d', actionName, actionValue)];  % Note the double backslash for \n
            state_human_sma.OutputActions.(actionName) = actionValue;
        end
    end
    if p.Results.showoutputactions
        stateDetails = [stateDetails actionDetails];  % Combine state and action details
    end
    mermaid_text = [mermaid_text sprintf('%s\n', stateDetails)];
    
    % -- Create transition/state change lines
    
    % If first state added, then it's the startpoint
    if current_state_number == 1
        mermaid_text = [mermaid_text sprintf('\t[*] --> %s\n', statename)];
    end

    % Handle timer
    target_id = sma.StateTimerMatrix(current_state_number);
    if target_id >= 65537
        % ! it seems that the id for >exit or >back can be different
        target_state = '[*]';  % this is Mermaid's start/endpoint
    else
        target_state = sma.StateNames{sma.StateTimerMatrix(current_state_number)};
    end
    state_human_sma.Tup = sma.StateTimers(current_state_number);
    target_state = fix_statename(target_state);
    if ~strcmp(statename, target_state)
        mermaid_text = [mermaid_text sprintf(state_time_transition_sprintf, ...
            statename, target_state, state_human_sma.Tup)];
        state_human_sma.StateChangeConditions.Tup = target_state;
    end
    
    % Handle other state change conditions
    input_matrix = sma.InputMatrix(current_state_number, :);
    changing_events = find(input_matrix ~= current_state_number);
    for event_code = changing_events
        event_name = BpodSystem.StateMachineInfo.EventNames{event_code};
        target_state_id = input_matrix(event_code);
        if target_state_id >= 65537
            target_state = '[*]';
        else
            target_state = sma.StateNames{target_state_id};
            target_state = fix_statename(target_state);
        end
        mermaid_text = [mermaid_text sprintf('\t%s --> %s: %s\n', ...
            statename, target_state, event_name)];
        state_human_sma.StateChangeConditions.(event_name) = target_state;
    end
    human_sma.(statename) = state_human_sma;

end

if p.Results.codewrap
    mermaid_text = ['```mermaid\n' mermaid_text '```'];
end

if p.Results.display
    fprintf([mermaid_text '\n'])
end

if hyphen_check
    warning('Renamed states with hyphens to have underscores')
    % neither MATLAB structs or Mermaid can handle hypthens in state names
end

if p.Results.createfile
    if isempty(p.Results.filepath)
        filepath = 'sma_diagram_output.md';
    else
        filepath = p.Results.filepath;
    end
    fid = fopen(filepath,'wt');
    fprintf(fid, mermaid_text);
    fclose(fid);
end
end

function modified_name = fix_statename(statename)
    modified_name = statename;
    modified_name(modified_name == '-') = '_';
end