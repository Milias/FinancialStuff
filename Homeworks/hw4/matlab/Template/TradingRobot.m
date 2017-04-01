classdef TradingRobot < AutoTrader
  properties
    AssetMgr = AssetManager;
    % This struct contains basic parameters of the algorithm.
    AlgoParams = struct('max_trading_volume', 0, 'lookback', 0, 'trigger_params', struct('tsmax', 0, 'tbmax', 0, 'ssmax', 0.0, 'sbmax', 0.0));

    % Placeholder struct to store performance-related stuff.
    PerfMeasure = struct;
  end

  methods
    function self = TradingRobot
      % Initializing the assets manager with the two ISINs.
      self.AssetMgr.Init({'DBK_EUR', 'CBK_EUR'});
    end

    function HandleDepthUpdate(self, ~, aDepth)
      % First the new book is stored.
      self.AssetMgr.UpdateDepths(aDepth);

      funct = {@Trade};
      feval(funct{1}, self, 'DBK_EUR', 22, 100);
    end

    function [theConfirmation] = Trade(self, aISIN, aP, aV)
      % Helper function for buying (aV > 0) and selling (aV < 0) stock.
      % Returns whether the order was successful or not.
      myCurrentTrades = size(self.ownTrades.price, 1);

      self.SendNewOrder(aP, abs(aV), sign(aV), {aISIN}, {'IMMEDIATE'}, 0);
      
      myTradeCount = size(self.ownTrades.price, 1) - myCurrentTrades;

      theConfirmation = myTradeCount > 0;
 
      if theConfirmation
        % Here we iterate over all the trades done (in case aV > first entry's volume),
        % updating our assets and book.
        for i = 1:myTradeCount
          fprintf('Trade (side: %d, %d): %7s, %3.2f, %3.0f\n', sign(aV), theConfirmation, aISIN, self.ownTrades.price(myCurrentTrades+i), sign(aV) * self.ownTrades.volume(myCurrentTrades+i));

          self.AssetMgr.UpdateAssets(aISIN, self.ownTrades.price(myCurrentTrades+i), sign(aV) * self.ownTrades.volume(myCurrentTrades+i));
        end
      end
    end

    function Unwind(self)
      clear self.AssetMgr;
    end
  end
end
