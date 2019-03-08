% Format: [Context(0/1) Choice(0/1) Reward?]
trial_list = [0 0 1;
              1 1 1;
              0 1 0;
              1 0 0];
trial_start_delay = 3; % s

num_trials = size(trial_list,1);
track_idx = 1;
unused_track_idx = 2;
maze.set_gates(track_idx, 0);
maze.set_gates(unused_track_idx, 0);
pause(1);

fprintf('Running %d trials...\n', num_trials);
for k = 1:num_trials
    % Setup trial
    trial_data = trial_list(k,:);
    fprintf('%s: TRIAL %d (Context=%d, Choice=%d, Reward=%d)\n',...
        datestr(now), k, trial_data(1), trial_data(2), trial_data(3));
    maze.set_context(track_idx, trial_data(1));
    maze.set_choice(track_idx, trial_data(2));
    
    fprintf('%s: Delay start for %.1f seconds... ', datestr(now), trial_start_delay);
    pause(trial_start_delay);
    fprintf('Done\n');
    
    maze.clear_prox;
    maze.set_gates(track_idx, 1); % Open gates
    
    fprintf('%s: Waiting for mouse to complete run... ', datestr(now));
    tic;
    while (true) % Wait for mouse to reach end
        if maze.check_end_prox(track_idx)
            break;
        end
    end
    t = toc;
    fprintf('Done (%.1f sec)\n', t);
    
    maze.set_gates(track_idx, 0); % Close gates
    pause(0.5); %  Gate can collide with platforms during motion...
    maze.set_context(track_idx, 0.5);
    maze.set_choice(track_idx, 0.5);
    
    maze.clear_prox;
    maze.set_gates(unused_track_idx, 1);
    
    fprintf('%s: Waiting for mouse to return to start... ', datestr(now));
    tic;
    while (true) % Wait for mouse to reach beginning
        if maze.check_start_prox(track_idx)
            break;
        end
    end
    t = toc;
    fprintf('Done (%.1f sec)\n', t);
    maze.set_gates(unused_track_idx, 0);
end