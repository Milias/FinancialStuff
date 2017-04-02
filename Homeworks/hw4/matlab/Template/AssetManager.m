classdef AssetManager < handle
  properties
    % Struct where we store the price and volume of our assets.
    % It's structure is self.Assets.ISIN = {struct('price', 0.0, 'volume', 0, 'index', 0)}.
    Assets = struct;
      
    % Struct of vectors containing depths for each ISIN.
    % Structure: self.DepthHistory.ISIN = {}.
    DepthHistory = struct;
      
    % Vector of stored ISINs.
    ISINs = cell(0);
    
    % Keeping track of how many book updates we've received.
    % Total,  and one index per ISIN.
    CurrentIndex = struct('total', 0);
  end

  methods
    function Init(self, aISINs)
      if nargin == 0
        aISINs = {};
      end

      for i = 1:size(aISINs, 2)
        self.CheckISIN(aISINs{i})
      end
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
      theIndices = cellfun(@(trade) trade.price < aP, self.Assets.(aISIN));
    end

    function {theData} = GetDataFromHistory(self, aISIN, aValue, aT)
      % Returns a cell of vectors containing aValue from the last aT depths from aISIN,
      % sorted from newest to oldest. NOTE: here aT counts global ticks, not only ticks
      % counted in self.CurrentIndex.(aISIN).

      theData = cellfun(@(depth) depth.(aValue), {self.DepthHistory.(aISIN){self.CurrentIndex.total:-1:max(1, self.CurrentIndex.total - aT)}})
    end

    function theMeanPrice = GetMeanPrice(self, aP, aV)
      theMeanPrice = sum(aP .* aV) / sum(aV);
    end

    function theTradeStruct = NewTrade(self, aP, aV)
      theTradeStruct = struct('price', aP, 'volume', aV, 'index', self.CurrentIndex.total);
    end

    function UpdateDepths(self, aDepth)
      % Increasing the amount of book updates we have received.
      self.CurrentIndex.total = self.CurrentIndex.total + 1;
      self.CurrentIndex.(aDepth.ISIN) = self.CurrentIndex.(aDepth.ISIN) + 1;

      % Copy depths for each ISIN.
      for myISIN = self.ISINs
        self.DepthHistory.(myISIN){end+1} = self.DepthHistory.(myISIN){end};
      end

      self.DepthHistory.(aDepth.ISIN){end} = aDepth;
    end

    function CheckISIN(self, aISIN)
      myTemp = strfind(self.ISINs, aISIN);
      if ~any(vertcat(myTemp{:}))
        self.ISINs{end+1} = aISIN;
        [self.CurrentIndex(:).(aISIN)] = 0;
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
      myIndex = cellfun(@(trade) abs(trade.price-aP)<0.01, self.Assets.(aISIN));
      
      if ~any(myIndex(:))
        % If there are no prices, we add a new trade.
        self.Assets.(aISIN){end+1} = self.NewTrade(aP, aV);
      else
        % Otherwise, the volume is updated and the time index
        % set to CurrentIndex.total
        myIndex = find(myIndex, 1);
        self.Assets.(aISIN){myIndex}.volume = self.Assets.(aISIN){myIndex}.volume + aV;
        self.Assets.(aISIN){myIndex}.index = self.CurrentIndex.total;
      end

      % Now we update our copy of the book.
      if aV > 0
        myPrice = 'askLimitPrice';
        myVolume = 'askVolume';
      else
        myPrice = 'bidLimitPrice';
        myVolume = 'bidVolume';
      end

      myIndex = abs(self.DepthHistory.(aISIN){end}.(myPrice) - aP) < 0.01;

      if abs(aV) < self.DepthHistory.(aISIN){end}.(myVolume)(myIndex)
        self.DepthHistory.(aISIN){end}.(myVolume)(myIndex) = self.DepthHistory.(aISIN){end}.(myVolume)(myIndex) - abs(aV);
      else
        self.DepthHistory.(aISIN){end}.(myVolume) = self.DepthHistory.(aISIN){end}.(myVolume)(~myIndex);
        self.DepthHistory.(aISIN){end}.(myPrice) = self.DepthHistory.(aISIN){end}.(myPrice)(~myIndex);
      end
    end
  end
end
