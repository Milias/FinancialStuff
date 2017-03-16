classdef AssetManager
  properties
    Assets
    Prices
  end

  methods
    function self = AssetsManager
      self.Assets = struct('price', [], 'volume', [], 'total_volume', 0);
      self.Prices = struct('EUR', struct('bid', [], 'ask', []), 'CHI', struct('bid', [], 'ask', []));
    end

    function theVolume = GetCurrentVolume(self, aP)
      myIndex = find(self.Assets.price == aP);
      if myIndex
        theVolume = self.Assets.volume(myIndex);
      else
        theVolume = 0;
      end
    end

    function theIndices = GetIndicesLowerThan(self, aP)
      theIndices = self.Assets.price < int32(100*aP);
    end

    function theMeanPrice = GetMeanPrice(self, prices, volume)
      theMeanPrice = sum(prices.*volume)/sum(volume);
    end

    function UpdatePrices(self, aDepth)
      myBidMean = self.GetMeanPrice(aDepth.bidLimitPrice, aDepth.bidVolume);
      myAskMean = self.GetMeanPrice(aDepth.askLimitPrice, aDepth.askVolume);

      switch aDepth.ISIN
      case 'CHI_AKZA'
        if size(aDepth.bidVolume, 1)
          self.Prices.CHI.bid = [ self.Prices.CHI.bid myBidMean ];
        else
          self.Prices.CHI.bid = [ self.Prices.CHI.bid self.Prices.CHI.bid(end) ];
        end

        if size(aDepth.askVolume, 1)
          self.Prices.CHI.ask = [ self.Prices.CHI.ask myAskMean ];
        else
          self.Prices.CHI.ask = [ self.Prices.CHI.ask self.Prices.CHI.ask(end) ];
        end

        self.Prices.EUR.bid = [ self.Prices.EUR.bid self.Prices.EUR.bid(end) ];
        self.Prices.EUR.ask = [ self.Prices.EUR.ask self.Prices.EUR.ask(end) ];

      case 'EUR_AKZA'
        if size(aDepth.bidVolume, 1)
          self.Prices.EUR.bid = [ self.Prices.EUR.bid myBidMean ];
        else
          self.Prices.EUR.bid = [ self.Prices.EUR.bid self.Prices.EUR.bid(end) ];
        end

        if size(aDepth.askVolume, 1)
          self.Prices.EUR.ask = [ self.Prices.EUR.ask myAskMean ];
        else
          self.Prices.EUR.ask = [ self.Prices.EUR.ask self.Prices.EUR.ask(end) ];
        end

        self.Prices.CHI.bid = [ self.Prices.CHI.bid self.Prices.CHI.bid(end) ];
        self.Prices.CHI.ask = [ self.Prices.CHI.ask self.Prices.CHI.ask(end) ];
      end
    end

    function UpdateAssets(self, aP, aV)
      % Here aP and aV are converted to integers so we can
      % look up their values using find().
      aP = int32(aP * 100);
      aV = int32(aV);

      myIndex = find(self.Assets.price == aP);

      if myIndex
        self.Assets.volume(myIndex) = self.Assets.volume(myIndex) + aV;
      else
        self.Assets.price = [ self.Assets.price aP ];
        self.Assets.volume = [ self.Assets.volume aV ];
      end

      self.Assets.total_volume = self.Assets.total_volume + aV;
    end
  end
end
