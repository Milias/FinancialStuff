classdef PlotFeedRobot < AutoTrader
  properties
    DepthHistory
  end

  methods
    function self = PlotFeedRobot
      self.DepthHistory = [];
    end

    function HandleDepthUpdate(self, ~, aDepth)
      self.DepthHistory = [ self.DepthHistory aDepth ];
    end
  end
end
