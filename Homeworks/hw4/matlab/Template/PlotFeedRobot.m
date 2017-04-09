classdef PlotFeedRobot < AutoTrader
  properties
    DepthHistory
  end

  methods
    function self = PlotFeedRobot
      self.DepthHistory = cell(0);
    end

    function HandleDepthUpdate(self, ~, aDepth)
      self.DepthHistory{length(self.DepthHistory) + 1} = aDepth;
    end
    
    function Unwind(self)
    end
  end
end

