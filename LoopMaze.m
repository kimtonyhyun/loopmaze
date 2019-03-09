classdef LoopMaze < handle
    properties (SetAccess=private)
        track_state
        params
    end
    
    properties (Hidden=true)
        a % Arduino object
    end
    
    methods
        function maze = LoopMaze(comPort)
            % Arduino pinout
            %------------------------------------------------------------
            p.track(1).context_step = 29; % Dir is expected to be pin "step"-2
            p.track(1).choice_step = 53;
            p.track(1).lick = 47;
            p.track(1).dose = 49;
            p.track(1).dose_duration = 27;
            p.track(1).start_gate = 2;
            p.track(1).end_gate = 3;
            p.track(1).start_prox = 14;
            p.track(1).end_prox = 15;
            
            p.track(2).context_step = 52; % Double check
            p.track(2).choice_step = 28; % Double check
            p.track(2).lick = 46; % Double check
            p.track(2).dose = 48; % Double check
            p.track(2).dose_duration = 50;
            p.track(2).start_gate = 4;
            p.track(2).end_gate = 5;
            p.track(2).start_prox = 15; % Note: these are the same devices as track1
            p.track(2).end_prox = 14;
            
            p.num_tracks = length(p.track);

            % Synchronization outputs
            p.sync.miniscope_trig = 13;
            p.sync.foot_pedal = 12;
            p.sync.og_led = 10;
            p.sync.clear_prox = 16;
            
            maze.params = p;
            
            % Establish access to Arduino
            %------------------------------------------------------------
            maze.a = arduino(comPort);

            % Set up digital pins
            for i = 1:maze.params.num_tracks
                tr = maze.params.track(i);
                maze.a.pinMode(tr.context_step, 'output');
                maze.a.pinMode(tr.context_step-2, 'output'); % dir
                maze.a.pinMode(tr.choice_step, 'output');
                maze.a.pinMode(tr.choice_step-2, 'output');
                maze.a.pinMode(tr.lick, 'input');
                maze.a.pinMode(tr.dose, 'output');
                maze.a.pinMode(tr.start_gate, 'output');
                maze.a.pinMode(tr.end_gate, 'output');
                maze.a.pinMode(tr.start_prox, 'input');
                maze.a.pinMode(tr.end_prox, 'input');
            end
            
            maze.a.pinMode(maze.params.sync.miniscope_trig, 'output');
            maze.a.pinMode(maze.params.sync.og_led, 'output');
            maze.a.pinMode(maze.params.sync.foot_pedal, 'input');
            maze.a.pinMode(maze.params.sync.clear_prox, 'output');
                       
            % Assume all corridors are in the plate position (0), rather
            %   than the mesh position (1)
            %------------------------------------------------------------
            maze.track_state = zeros(p.num_tracks, 2); % Dim2: [Context Choice]
            
            % Initialize apparatus
            maze.clear_prox;
        end
        
        % Reward controls
        %------------------------------------------------------------
        function dose(maze, track_idx)
            dose_pin = maze.params.track(track_idx).dose;
            dose_duration = maze.params.track(track_idx).dose_duration;
            maze.a.send_pulse(dose_pin, dose_duration);
        end
        
        function lick = is_licking(maze, track_idx)
            lick_pin = maze.params.track(track_idx).lick;
            lick = maze.a.digitalRead(lick_pin);
        end
        
        % Prox sensor controls
        %------------------------------------------------------------
        function prox_tripped = check_start_prox(maze, track_idx)
            prox_pin = maze.params.track(track_idx).start_prox;
            val = maze.a.digitalRead(prox_pin);
            prox_tripped = (val == 1);
        end
        
        function prox_tripped = check_end_prox(maze, track_idx)
            prox_pin = maze.params.track(track_idx).end_prox;
            val = maze.a.digitalRead(prox_pin);
            prox_tripped = (val == 1);
        end
        
        function clear_prox(maze)
            maze.a.digitalWrite(maze.params.sync.clear_prox, 1);
            pause(0.1);
            maze.a.digitalWrite(maze.params.sync.clear_prox, 0);
        end
        
        % Platform controls
        %------------------------------------------------------------
        function set_context(maze, track_idx, target)
            step_pin = maze.params.track(track_idx).context_step;
            current = maze.track_state(track_idx,1);
            maze.track_state(track_idx,1) = maze.set_stepper(step_pin, current, target);
        end
        
        function flip_context(maze, track_idx)
            current = maze.track_state(track_idx,1);
            if (current == 0)
                target = 1;
            else
                target = 0;
            end
            maze.set_context(track_idx, target);
        end
        
        function set_choice(maze, track_idx, target)
            step_pin = maze.params.track(track_idx).choice_step;
            current = maze.track_state(track_idx,2);
            maze.track_state(track_idx,2) = maze.set_stepper(step_pin, current, target);
        end
        
        function flip_choice(maze, track_idx)
            current = maze.track_state(track_idx, 2);
            if (current == 0)
                target = 1;
            else
                target = 0;
            end
            maze.set_choice(track_idx, target);
        end
        
        function reset_platforms(maze)
            for i = 1:maze.params.num_tracks
                maze.set_context(i,0);
                maze.set_choice(i,0);
            end
        end
        
        function target = set_stepper(maze, step_pin, current, target)
            % target == 0: Go to steel plate
            % target == 0.5: 90 deg
            % target == 1: Go to mesh
            target = max(0, target); % If target < 0, set to 0
            target = min(1, target); % If target > 1, set to 1
            
            if (target ~= current)
                direction = (target > current);
                num_90degs = abs(target-current)*2;
                maze.a.rotate_stepper(step_pin, direction, num_90degs);
            end
        end
        
        % Gate controls
        %------------------------------------------------------------
        function close_gates(maze, track_idx)
            tr = maze.params.track(track_idx);
            maze.a.digitalWrite(tr.end_gate, 0);
            maze.a.digitalWrite(tr.start_gate, 0);
        end
        
        function open_gates(maze, track_idx)
            tr = maze.params.track(track_idx);
            maze.a.digitalWrite(tr.end_gate, 1);
            maze.a.digitalWrite(tr.start_gate, 1);
        end
        
        function set_gates(maze, track_idx, target)
            if (target > 0)
                maze.open_gates(track_idx);
            else
                maze.close_gates(track_idx);
            end
        end
        
        % Synchronization
        %------------------------------------------------------------
        function miniscope_start(maze)
            maze.a.digitalWrite(maze.params.sync.miniscope_trig, 1);
        end
        
        function miniscope_stop(maze)
            maze.a.digitalWrite(maze.params.sync.miniscope_trig, 0);
        end
        
        function opto_on(maze)
            maze.a.digitalWrite(maze.params.sync.og_led, 1);
        end
        
        function opto_off(maze)
            maze.a.digitalWrite(maze.params.sync.og_led, 0);
        end
        
        function press = pedal_is_pressed(maze)
            val = maze.a.digitalRead(maze.params.sync.foot_pedal);
            press = (val == 1);
        end
    end
end