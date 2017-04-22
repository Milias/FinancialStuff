classdef Profiler < handle
  properties
    TimersData
    TimersTic
    TimersCheck
  end

  methods
    function self = Profiler
      self.TimersData = struct;
      self.TimersTic = struct;
      self.TimersCheck = struct;
    end

    function delete(self)
      clear self.TimersData;
      clear self.TimersTic;
      clear self.TimersCheck;
    end

    function StartTimer(self, aTimer)
      if isfield(self.TimersCheck, aTimer)
        if self.TimersCheck.(aTimer)
          fprintf('WARNING: last timer from %s not unchecked.\n\n', aTimer)
          error('Stoping')
        end
      end
      self.TimersCheck.(aTimer) = 1;
      self.TimersTic.(aTimer) = tic;
    end

    function StopTimer(self, aTimer)
      if isfield(self.TimersData, aTimer)
        self.TimersData.(aTimer).Time = self.TimersData.(aTimer).Time + toc(self.TimersTic.(aTimer));
        self.TimersData.(aTimer).Count = self.TimersData.(aTimer).Count + 1;
      else
        self.TimersData.(aTimer).Time = toc(self.TimersTic.(aTimer));
        self.TimersData.(aTimer).Count = 1;
      end

      self.TimersCheck.(aTimer) = 0;
    end

    function PrintAll(self)
      timers = fieldnames(self.TimersData);
      for i = 1:length(timers)
        timer = timers{i};
        fprintf('Timer: %s, Time: %fs, Count: %d, Avg: %f\n', timer, self.TimersData.(timer).Time, self.TimersData.(timer).Count, self.TimersData.(timer).Time/self.TimersData.(timer).Count)
      end
    end

    function theTotal = Total(self)
      theTotal = sum(cellfun(@(field) self.TimersData.(field), fieldnames(self.TimersData)));
    end
  end
end
