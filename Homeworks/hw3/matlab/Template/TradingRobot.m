classdef TradingRobot < AutoTrader
  properties
    EURDepth
    CHIDepth
  end

  methods
    function self = TradingRobot
      self.EURDepth = struct('ISIN', 'EUR_AKZA', 'tickSize', 0.0, 'bidLimitPrice', [], 'bidVolume', [], 'askLimitPrice', [], 'askVolume', []);

      self.CHIDepth = struct('ISIN', 'CHI0_AKZA', 'tickSize', 0.0, 'bidLimitPrice', [], 'bidVolume', [], 'askLimitPrice', [], 'askVolume', []);
    end

    function HandleDepthUpdate(self, ~, aDepth)
      % Saves last depth
      switch aDepth.ISIN
      case 'EUR_AKZA'
        self.EURDepth = aDepth;
      case 'CHI_AKZA'
        self.CHIDepth = aDepth;
      end

      self.Arbitrage();
    end

    function UpdateSavedDepth(self, aDepth, aP, aV)
      % aV > 0 means buy, aV < 0 means sell.
      if aV > 0
        myPrice = aDepth.askLimitPrice;
        myVolume = aDepth.askVolume;
      else
        myPrice = aDepth.bidLimitPrice;
        myVolume = aDepth.bidVolume;
      end

      myIndex = abs(myPrice - aP) < 0.001;
      if int32(abs(aV)) == int32(myVolume(myIndex))
        myPrice = myPrice(myIndex == false);
        myVolume = myVolume(myIndex == false);
      else
        myVolume(myIndex) = myVolume(myIndex) - abs(aV);
      end

      switch aDepth.ISIN
      case 'EUR_AKZA'
        if aV > 0
          self.EURDepth.askLimitPrice = myPrice;
          self.EURDepth.askVolume = myVolume;
        else
          self.EURDepth.bidLimitPrice = myPrice;
          self.EURDepth.bidVolume = myVolume;
        end
      case 'CHI_AKZA'
        if aV > 0
          self.CHIDepth.askLimitPrice = myPrice;
          self.CHIDepth.askVolume = myVolume;
        else
          self.CHIDepth.bidLimitPrice = myPrice;
          self.CHIDepth.bidVolume = myVolume;
        end
      end
    end

    function [theConfirmation] = Buy(self, aISIN, aP, aV)
      myCurrentTrades = size(self.ownTrades.price, 1);

      self.SendNewOrder(aP, aV, 1, {aISIN}, {'IMMEDIATE'}, 0);

      theConfirmation = size(self.ownTrades.price, 1) > myCurrentTrades;
      fprintf('Buy  (%d): %10s, %3.2f, %3.0f\n', theConfirmation, aISIN, aP, aV);

      switch aISIN
      case 'EUR_AKZA'
        self.UpdateSavedDepth(self.EURDepth, aP, aV);
      case 'CHI_AKZA'
        self.UpdateSavedDepth(self.CHIDepth, aP, aV);
      end
    end

    function [theConfirmation] = Sell(self, aISIN, aP, aV)
      myCurrentTrades = size(self.ownTrades.price, 1);

      self.SendNewOrder(aP, aV, -1, {aISIN}, {'IMMEDIATE'}, 0);

      theConfirmation = size(self.ownTrades.price, 1) > myCurrentTrades;
      fprintf('Sell (%1d): %10s, %3.2f, %3.0f\n', theConfirmation, aISIN, aP, aV);

      switch aISIN
      case 'EUR_AKZA'
        self.UpdateSavedDepth(self.EURDepth, aP, -aV);
      case 'CHI_AKZA'
        self.UpdateSavedDepth(self.CHIDepth, aP, -aV);
      end
    end

    function Arbitrage(self)
      myIndexCE = bsxfun(@lt, self.CHIDepth.askLimitPrice', self.EURDepth.bidLimitPrice);
      myIndexEC = bsxfun(@lt, self.EURDepth.askLimitPrice', self.CHIDepth.bidLimitPrice);

      if any(myIndexCE)
        [ myPricesX, myPricesY ] = ndgrid(self.CHIDepth.askLimitPrice, self.EURDepth.bidLimitPrice);
        [ myVolumesX, myVolumesY ] = ndgrid(self.CHIDepth.askVolume, self.EURDepth.bidVolume);
        myLimitVolume = arrayfun(@min, myVolumesX, myVolumesY);

        myConfirmation = arrayfun(@(aP, aV) self.Buy('CHI_AKZA', aP, aV), myPricesX(myIndexCE), myLimitVolume(myIndexCE));

        arrayfun(@(aP, aV, aC) self.Sell('EUR_AKZA', aP, aV*aC), myPricesY(myIndexCE), myLimitVolume(myIndexCE), myConfirmation);
      end

      if any(myIndexEC)
        [ myPricesX, myPricesY ] = ndgrid(self.EURDepth.askLimitPrice, self.CHIDepth.bidLimitPrice);
        [ myVolumesX, myVolumesY ] = ndgrid(self.EURDepth.askVolume, self.CHIDepth.bidVolume);
        myLimitVolume = arrayfun(@min, myVolumesX, myVolumesY);

        myConfirmation = arrayfun(@(aP, aV) self.Buy('EUR_AKZA', aP, aV), myPricesX(myIndexEC), myLimitVolume(myIndexEC));

        arrayfun(@(aP, aV, aC) self.Sell('CHI_AKZA', aP, aV*aC), myPricesY(myIndexEC), myLimitVolume(myIndexEC), myConfirmation);
      end
    end
  end
end
