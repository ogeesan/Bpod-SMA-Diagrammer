# Bpod-SMA-Diagrammer
This repository contains `sma_diagram.m` which allows Bpod users to build state diagrams using Mermaid.

It's primary purpose is to visualise the state matricies. In this regard, it's useful for troubleshooting/developing a protocol, as well as the documentation and sharing of information about the trial structures.

## Usage
```matlab
sma = NewStateMachine()
% ... [Your code using AddState() to build a state machine] ...

[mermaid_text, sma_struct] = sma_diagram(sma);
% this also prints the mermaid diagram into console by default

```

Check `diagram_sma.m` for optional parameters (e.g. `diagram_sma(sma, 'display', false)`).

`sma_struct` is a human-readable structure of the state matrix, which you may find useful to insert into `BpodSystem.Data` so that `SessionData` contains the matrix for later reference (if your protocol tends to undergo changes).

## A brief word on Mermaid
[Mermaid](https://mermaid.js.org/intro/) is a "charting tool that renders Markdown-inspired text definitions to create and modify diagrams dynamically". The reason for its usefulness in the Bpod context is that it's wise to store a `readme.md` within each Bpod protocol file for documentation purposes, and having a schematic of the trial structure can be a useful way of sharing information about how it works.

## Example of usage
I added `sma_diagram(sma)` into Bpod's example protocol [`Examples/Protocols/Light/Light2AFC`](https://github.com/sanworks/Bpod_Gen2/blob/master/Examples/Protocols/Operant/Operant.m) (after `sma` construction Line 119 in the protocol). The first trial happened to be trial type 1, and the raw output embedded in markdown looks like this:
```mermaid
stateDiagram-v2
WaitForPoke: WaitForPoke
	[*] --> WaitForPoke
	WaitForPoke --> CueDelay: Port2In
CueDelay: CueDelay
	CueDelay --> WaitForPortOut: Tup (0.200) 
	CueDelay --> WaitForPoke: Port2Out
WaitForPortOut: WaitForPortOut\nPWM1 255
	WaitForPortOut --> WaitForResponse: Port2Out
WaitForResponse: WaitForResponse\nPWM1 255
	WaitForResponse --> [*]: Tup (5.000) 
	WaitForResponse --> LeftRewardDelay: Port1In
	WaitForResponse --> Punish: Port3In
LeftRewardDelay: LeftRewardDelay
	LeftRewardDelay --> LeftReward: Tup (0.000) 
	LeftRewardDelay --> CorrectEarlyWithdrawal: Port1Out
Punish: Punish
	Punish --> [*]: Tup (3.000) 
LeftReward: LeftReward\nValve1 1
	LeftReward --> Drinking: Tup (0.030) 
CorrectEarlyWithdrawal: CorrectEarlyWithdrawal
	CorrectEarlyWithdrawal --> [*]: Tup (0.000) 
RightRewardDelay: RightRewardDelay
	RightRewardDelay --> RightReward: Tup (0.000) 
	RightRewardDelay --> CorrectEarlyWithdrawal: Port3Out
RightReward: RightReward\nValve3 1
	RightReward --> Drinking: Tup (0.031) 
Drinking: Drinking
	Drinking --> DrinkingGrace: Port1Out
	Drinking --> DrinkingGrace: Port3Out
DrinkingGrace: DrinkingGrace
	DrinkingGrace --> [*]: Tup (0.500) 
	DrinkingGrace --> Drinking: Port1In
	DrinkingGrace --> Drinking: Port3In
```

The first few lines of text used to build this diagram (as they appear in the markdown file) look like the following:

```
stateDiagram-v2
WaitForPoke: WaitForPoke
	[*] --> WaitForPoke
	WaitForPoke --> CueDelay: Port2In
CueDelay: CueDelay
	CueDelay --> WaitForPortOut: Tup (0.200) 
	CueDelay --> WaitForPoke: Port2Out
WaitForPortOut: WaitForPortOut\nPWM1 255
	WaitForPortOut --> WaitForResponse: Port2Out
WaitForResponse: WaitForResponse\nPWM1 255
	WaitForResponse --> [*]: Tup (5.000) 
	WaitForResponse --> LeftRewardDelay: Port1In
	WaitForResponse --> Punish: Port3In
```


Mermaid is rendered by GitHub when presented in Markdown files. This is the raw output from my tool, built from a single trials' state matrix. With some small tweaks, it can represent the entire task with its different contingencies more generally. To do that, you'll have to refer to the [documentation on state diagrams](https://mermaid.js.org/syntax/stateDiagram.html). For example, in the above diagram I'd modify the transitions from `WaitForResponse` so that there is a line with `Port3In` to `RightRewardDelay`, and the connection to `Punish` could read "`Port1In or Port3In`". There are other visual tools available for the state diagram that you might like to look into if you have complex contingencies.