classdef TradingRobot < AutoTrader
  properties
    EURDepth
    CHIDepth

    AssetMgr
    Params
  end

  methods
    function self = TradingRobot
      self.AssetMgr = AssetManager;
      self.Params = struct('volume_limit', 100);
    end

    function HandleDepthUpdate(self, ~, aDepth)
      % Saves mean price
      %self.AssetMgr.UpdatePrices(aDepth)
      %disp(self.AssetMgr.Assets.total_volume)

      % Saves last depth
      switch aDepth.ISIN
      case 'EUR_AKZA'
        self.EURDepth = aDepth;
        self.EURArbitrage();
      case 'CHI_AKZA'
        self.CHIDepth = aDepth;
        self.CHIArbitrage();
      end
    end

    function Buy(self, aISIN, aP, aV)
      % Making sure we don't buy more than the limit.
      aV = min(aV, self.Params.volume_limit);

      myCurrentTrades = size(self.ownTrades.price, 1);

      self.SendNewOrder(aP, aV, 1, {aISIN}, {'IMMEDIATE'}, 0);

      % Updating assets if the trade was successful.
      if size(self.ownTrades.price, 1) > myCurrentTrades
        self.AssetMgr.UpdateAssets(aP, aV);
      end
    end

    function Sell(self, aISIN, aP, aV)
      % Making sure we don't sell more than what we have
      aV = min(max(self.AssetMgr.Assets.total_volume, 0), aV);

      myCurrentTrades = size(self.ownTrades.price, 1);

      self.SendNewOrder(aP, aV, -1, {aISIN}, {'IMMEDIATE'}, 0);

      % Updating assets if the trade was successful.
      if size(self.ownTrades.price, 1) > myCurrentTrades
        self.AssetMgr.UpdateAssets(aP, -aV);
      end
    end

    function CHIArbitrage(self)
      for i = 1:size(self.CHIDepth.askLimitPrice, 1)
        self.Buy('CHI_AKZA', self.CHIDepth.askLimitPrice(i), self.CHIDepth.askVolume(i));
      end
    end

    function EURArbitrage(self)
      for i = 1:size(self.EURDepth.bidLimitPrice, 1)
        myIndex = self.AssetMgr.GetIndicesLowerThan(self.EURDepth.bidLimitPrice(i));

        self.Sell('EUR_AKZA', self.EURDepth.bidLimitPrice(i), min(self.EURDepth.bidVolume(i), sum(self.AssetMgr.Assets.volume(myIndex))));
      end
    end
  end
end
