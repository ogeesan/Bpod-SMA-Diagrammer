function sma = get_example_sma(task)
% sma = get_example_sma(task)
% Retrieve an example sma without having to start a protocol
%
% There are some benefits to building state machines in functions, in part because
% developing and troubleshooting them could be done outside of having to run
% the protocol. Here's a sample of how that could be done.
%
% Tasks: 'discrimination', 'detection', 'test'

if strcmp(task,'discrimination')
    actions.image_ttl = {'BNCState', 1};
    actions.lick = 'Port1In';
    actions.initialdelaytime = 2;
    actions.restartinitialdelaytime = 0.5;
    actions.use_abortbaselinelick = true;
    actions.aborttime = 1;
    actions.use_delay = true;
    actions.baselinetime = 2;
    actions.stimulustime = 1;
    actions.deliverstimulus = {'BNCState', 2};
    actions.delaytime = 1;
    actions.earlylicktime = 1;
    actions.hittime = 1;
    actions.watertime = 3;
    actions.deliverreward = {'Valve', 1};
    actions.use_autohit = false;
    actions.misstime = 1;
    actions.waitforlicktime = 1;
    actions.posttime = 3;
    actions.iti = 3;


    sma = BuildSMA(5, 'go', actions);
elseif strcmp(task, 'detection')
    sma = BuildSMAGlobalTimer();
elseif strcmp(task, 'test')
    sma = NewStateMachine();
    sma = AddState(sma, 'Name', 'Start', ...
    'Timer', 1,...
    'StateChangeConditions', {'Tup', 'Number1'},...
    'OutputActions', {});
    sma = AddState(sma, 'Name', 'Number1', ...
    'Timer', 1,...
    'StateChangeConditions', {'Tup', 'Number2-1', 'Port1In', 'Number2-2'},...
    'OutputActions', {'BNCState', 3});
    sma = AddState(sma, 'Name', 'Number2-1', ...
    'Timer', 1,...
    'StateChangeConditions', {'Port2In', 'exit'},...
    'OutputActions', {});
    sma = AddState(sma, 'Name', 'Number2-2', ...
    'Timer', 1,...
    'StateChangeConditions', {'Port2In', 'exit', 'Tup', 'exit'},...
    'OutputActions', {});
else
    error('not recognised.')
end
end

function sma = BuildSMA(task_stage, trialtype, actions)
% Constructs a Bpod state matrix
% sma = BuildSMA(task_stage, trialtype, actions)
% Parameters
% ----------
%   task_stage : int
%                number for stage, determines which components of the task
%                are engaged
%   trialtype : str
%               'go' or 'nogo', determines if lick results in reward or not
%   actions : struct
%             contains informatino of what state machine inputs/ouputs are

use_abortbaselinelick = actions.use_abortbaselinelick;
use_delay = actions.use_delay;

if task_stage <5
    assert(strcmp(trialtype,'go'),'Early stages only supports Go trials.')
end

sma = NewStateMachine();

sma = AddState(sma, 'Name', 'TrueTrialStart', ...
    'Timer', 0.1,...
    'StateChangeConditions', {'Tup', 'InitialDelay'},...
    'OutputActions', actions.image_ttl);

sma = AddState(sma, 'Name', 'InitialDelay', ...
    'Timer', actions.initialdelaytime,...
    'StateChangeConditions', {'Tup', 'StartTrial', actions.lick, 'RestartInitialDelay'},...
    'OutputActions', {});

sma = AddState(sma, 'Name', 'RestartInitialDelay', ...
    'Timer', actions.restartinitialdelaytime,...
    'StateChangeConditions', {'Tup', 'InitialDelay'},...
    'OutputActions', {});

sma = AddState(sma, 'Name', 'StartTrial', ...
    'Timer', 0, ...
    'StateChangeConditions', {'Tup', 'Baseline'},...
    'OutputActions', {});

if use_abortbaselinelick
    % Abort the trial if mouse pre-licks before stimulus delivery
    baselineaction = {'Tup', 'Stimulus', actions.lick, 'AbortTrial'};
    sma = AddState(sma, 'Name', 'AbortTrial', ...
        'Timer', actions.aborttime,...
        'StateChangeConditions', {'Tup', 'ITI'},...
        'OutputActions', {});
else
    baselineaction = {'Tup', 'Stimulus'};
end

sma = AddState(sma, 'Name', 'Baseline', ...
    'Timer', actions.baselinetime,...
    'StateChangeConditions',baselineaction,...
    'OutputActions', {});

if use_delay
    changecondition = {actions.lick, 'EarlyLick', 'Tup', 'Delay'};
else
    changecondition = {'Tup', 'WaitForLick'};
end

sma = AddState(sma, 'Name', 'Stimulus', ...
    'Timer', actions.stimulustime,...
    'StateChangeConditions', changecondition,...
    'OutputActions', actions.deliverstimulus);

if use_delay
    % Prevent the mouse from receiving a reward if it licks too early
    sma = AddState(sma, 'Name', 'Delay', ...
        'Timer', actions.delaytime,...
        'StateChangeConditions', {actions.lick, 'EarlyLick', 'Tup','WaitForLick'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'EarlyLick',...
        'Timer', actions.earlylicktime, ...,
        'StateChangeConditions', {'Tup', 'Post'},... %! this should be optional punishment
        'OutputActions', {});
end


if strcmp(trialtype,'go')

    sma = AddState(sma, 'Name', 'Hit', ...  % Originally called TriggerReward
        'Timer', actions.hittime,...
        'StateChangeConditions', {'Tup', 'DeliverReward'},...
        'OutputActions', {});

    sma = AddState(sma, 'Name', 'DeliverReward',...
        'Timer',actions.watertime,...
        'StateChangeConditions',{'Tup','Post'},...
        'OutputActions', actions.deliverreward);

    if actions.use_autohit
        % In early training mouse will receive a reward at the end of the
        % trial anyway. It should be called its own state so we can
        % differentiate between auto-reward and truly triggered reward.
        changecondition = {actions.lick, 'Hit', 'Tup', 'HitAnyway'};
        sma = AddState(sma, 'Name', 'HitAnyway', ...
            'Timer', actions.hittime,...
            'StateChangeConditions', {'Tup', 'DeliverReward'},...
            'OutputActions', {});
    else
        changecondition = {actions.lick, 'Hit', 'Tup', 'Miss'};
        sma = AddState(sma, 'Name', 'Miss',...
            'Timer', actions.misstime,...
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions', {});

    end
elseif strcmp(trialtype,'nogo')
    changecondition = {actions.lick, 'FalseAlarm', 'Tup', 'CorrectRejection'};
    sma = AddState(sma, 'Name', 'FalseAlarm',...
        'Timer', actions.falsealarmtime,...
        'StateChangeConditions', {'Tup', 'ITI'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'CorrectRejection',...
        'Timer', actions.correctrejectiontime,...
        'StateChangeConditions', {'Tup', 'ITI'},...
        'OutputActions', {});
end

% This state is where the mouse reports its decision
sma = AddState(sma, 'Name', 'WaitForLick', ...
    'Timer', actions.waitforlicktime,...
    'StateChangeConditions', changecondition,...
    'OutputActions', {});

sma = AddState(sma, 'Name', 'Post',...
    'Timer', actions.posttime,...
    'StateChangeConditions',{'Tup', 'ITI'},...
    'OutputActions', {});

sma = AddState(sma, 'Name', 'ITI',...
    'Timer', actions.iti,...
    'StateChangeConditions',{'Tup', 'ExitTrial'},...
    'OutputActions', {});

sma = AddState(sma, 'Name', 'ExitTrial',...
    'Timer', 0,...
    'StateChangeConditions',{'Tup', 'exit'},...
    'OutputActions', {});
end

function sma = BuildSMAGlobalTimer()
ImageBNC = 2;
RewardOutputAction = {'ValveState', 3};
WaterTime = 0.3213;
Baseline2SCC = {'Tup', 'ITI','Port1In','ResetTimerForDrinking'}; % PortXIn
DeliverRewardSCC = {'Tup', 'StillDrinking'};
S.GUI.PreWait = 2;
S.GUI.Wait4Trial = 0;
S.Baseline2 = 3;
S.ToneTime = 3;
S.ITI = 4;
sma = NewStateMachine();
    
sma = AddState(sma, 'Name', 'Initialdelay', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup', 'TriggerTrial'},...
    'OutputActions', {'Serial1','Z'}); % Z = reset wheel position to 0, isn't really required

% TriggerTrial and Wait4Trial add up to form the baseline
sma = AddState(sma, 'Name', 'TriggerTrial', ... % start logging of wheel and 2P data
    'Timer', S.GUI.PreWait,...
    'StateChangeConditions', {'Tup', 'ZeroWait4Trial'},...
    'OutputActions', {'Serial1','L','BNCState',ImageBNC}); % L = resets pos to 0, clear SD, start logging position+time data to SD
sma = AddState(sma, 'Name', 'ZeroWait4Trial',...
    'Timer', 0,...
    'StateChangeConditions',{'Tup','Wait4Trial'},...
    'OutputActions',{'Serial1','Z','BNCState',ImageBNC}); % zero position
sma = AddState(sma, 'Name', 'Wait4Trial', ...
    'Timer', S.GUI.Wait4Trial,...
    'StateChangeConditions', {'Tup', 'ZeroTrial','Serial1_1', 'Initialdelay'},...
    'OutputActions', {'Serial1','E','BNCState',ImageBNC}); % E = enables all thresholds, as they're disabled when they're crossed

% play tone for S.ToneTime seconds, but lead to reward or no reward based on Threshold2
sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', S.ToneTime); % create timer which defines tone length
sma = AddState(sma, 'Name', 'ZeroTrial', ... % effectively the start of the tone
    'Timer', 0,...
    'StateChangeConditions', {'Tup', 'Trial'},...
    'OutputActions', {'Serial1','Z','BNCState',ImageBNC,'GlobalTimerTrig',1}); % Z = 0 position, trigger the global timer1
sma = AddState(sma, 'Name', 'Trial', ...
    'Timer',0,...
    'StateChangeConditions', {'GlobalTimer1_End','Baseline2', 'Serial1_2', 'TriggerReward'},...
    'OutputActions', {'Serial1','E','BNCState',3}); % Enable thresholds, continue acq and present tone
sma = AddState(sma, 'Name', 'TriggerReward',...
    'Timer', 0,...
    'StateChangeConditions', {'GlobalTimer1_End','DeliverReward'},... % consider adding some sort of failsafe Tup?
    'OutputActions',{'BNCState',3}); % tone/acq being triggered until end of GlobalTimer

sma = AddState(sma, 'Name', 'DeliverReward', ...
    'Timer', WaterTime,...
    'StateChangeConditions', DeliverRewardSCC,... % dependent on S.Imaging
    'OutputActions', RewardOutputAction);

% StillDrinking loop
sma = AddState(sma,'Name', 'StillDrinking', ...
    'Timer', 1, ...
    'StateChangeConditions', {'Tup', 'Baseline2','Port1In','ResetTimerForDrinking'},... % PortXIn loop
    'OutputActions', {'BNCState',ImageBNC});
sma = AddState(sma,'Name', 'ResetTimerForDrinking', ...
    'Timer', 0, ...
    'StateChangeConditions', {'Tup', 'StillDrinking',},...
    'OutputActions', {'BNCState',ImageBNC});

sma = AddState(sma, 'Name', 'Baseline2', ...
    'Timer', S.Baseline2,...
    'StateChangeConditions', Baseline2SCC,... % dependent on S.Imaging
    'OutputActions', {'BNCState',ImageBNC});

sma = AddState(sma, 'Name', 'ITI', ...
    'Timer', S.ITI,...
    'StateChangeConditions', {'Tup', 'TrialEnd'},...
    'OutputActions', {});

sma = AddState(sma, 'Name', 'TrialEnd', ...
    'Timer', 0,...
    'StateChangeConditions', {'Tup', 'exit'},...
    'OutputActions', {'Serial1','F'}); % finish logging position+time data
end