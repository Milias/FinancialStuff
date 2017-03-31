classdef TradingRobot < AutoTrader
  properties
    AssetMgr
  end

  methods
    function self = TradingRobot
      % Initializing the assets manager with the two ISINs.
      self.AssetMgr = AssetManager({'DBK_EUR', 'CBK_EUR'});
    end

    function HandleDepthUpdate(self, ~, aDepth)
      % First the new book is stored.
      self.AssetMgr.UpdateDepths(aDepth);
    end

    function [theConfirmation] = Trade(self, aISIN, aP, aV)
      % Helper function for buying (aV > 0) and selling (aV < 0) stock.
      myCurrentTrades = size(self.ownTrades.price, 1);

      self.SendNewOrder(aP, abs(aV), sign(aV), {aISIN}, {'IMMEDIATE'}, 0);

      theConfirmation = size(self.ownTrades.price, 1) > myCurrentTrades;
      fprintf('Trade (side: %d, %d): %7s, %3.2f, %3.0f\n', sign(aV), theConfirmation, aISIN, aP, abs(aV));

      self.AssetMgr.UpdateAssets(aISIN, aP, aV);
    end

    function Unwind(self)
    end
  end
end
