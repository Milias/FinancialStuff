classdef AssetManager
  properties
    ISINs
    Assets
    DepthHistory

    CurrentUpdateIndex
    CurrentDepth
  end

  methods
    function self = AssetManager(aISINs)
      if nargin == 0
        aISINs = {};
      end

      % Struct where we store the price and volume of our assets.
      % It's structure is self.Assets.ISIN = {struct('price', 0.0, 'volume', 0, 'index', 0)}.
      self.Assets = struct;
      
      % Struct of vectors containing depths for each ISIN.
      % Structure: self.DepthHistory.ISIN = {}.
      self.DepthHistory = struct;
      
      % Vector of stored ISINs.
      self.ISINs = cell(0);
      for i = 1:size(aISINs, 2)
        self.CheckISIN(aISINs{i});
      end

      % Keeping track of how many book updates we've received.
      CurrentUpdateIndex = 0;
    end

    function theVolume = GetCurrentVolume(self, aISIN, aP)
      myIndex = find(cellfun(@(trade) abs(trade.price-aP)<0.01, self.Assets.(aISIN)), 1);
      if any(myIndex(:))
        theVolume = self.Assets.(aISIN).volume(myIndex);
      else
        theVolume = 0;
      end
    end

    function theIndices = GetIndicesLowerThan(self, aISIN, aP)
      theIndices = self.Assets.price < aP;
    end

    function theMeanPrice = GetMeanPrice(self, aP, aV)
      theMeanPrice = sum(aP.*aV)/sum(aV);
    end

    function theTradeStruct = NewTrade(self, aP, aV)
      theTradeStruct = struct('price', aP, 'volume', aV, 'index', CurrentUpdateIndex);
    end

    function UpdateDepths(self, aDepth)
      self.AddToCellArray(self.DepthHistory.(aDepth.ISIN), aDepth);
      self.CurrentDepth = aDepth;
      self.CurrentUpdateIndex = self.CurrentUpdateIndex + 1;
    end

    function AddToCellArray(self, aCell, aNew)
      aCell{size(aCell, 2) + 1} = aNew;
    end

    function CheckISIN(self, aISIN)
      myTemp = strfind(self.ISINs, aISIN);
      if any(vertcat(myTemp{:}))
        self.AddToCellArray(self.ISINs, aISIN);
        [self.Assets(:).(aISIN)] = cell(0);
        [self.DepthHistory(:).(aISIN)] = cell(0);
      end
    end

    function UpdateAssets(self, aISIN, aP, aV)
      % Checking that aISIN is in our assets.
      % In this case we don't need it, since we already know the ISINs from the
      % beginning.
      % self.CheckISIN(aISIN);

      % First we find the index of the trade with the same price.
      myIndex = find(cellfun(@(trade) abs(trade.price-aP)<0.01, self.Assets.(aISIN)), 1);
      
      if any(myIndex(:))
        % If there are no prices, we add a new trade.
        self.AddToCellArray(self.Assets.(aISIN), self.NewTrade(aP, aV));
      else
        % Otherwise, the volume is updated and the time index
        % set to CurrentUpdateIndex.
        self.Assets.(aISIN).volume = self.Assets.(aISIN).volume + aV;
        self.Assets.(aISIN).index = CurrentUpdateIndex;
      end
    end
  end
end
