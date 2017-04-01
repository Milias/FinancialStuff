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
    CurrentUpdateIndex = 0;
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

    function theMeanPrice = GetMeanPrice(self, aP, aV)
      theMeanPrice = sum(aP .* aV) / sum(aV);
    end

    function theTradeStruct = NewTrade(self, aP, aV)
      theTradeStruct = struct('price', aP, 'volume', aV, 'index', self.CurrentUpdateIndex);
    end

    function UpdateDepths(self, aDepth)
      self.CurrentUpdateIndex = self.CurrentUpdateIndex + 1;
      self.DepthHistory.(aDepth.ISIN){size(self.DepthHistory.(aDepth.ISIN), 2) + 1} = aDepth;
    end

    function CheckISIN(self, aISIN)
      myTemp = strfind(self.ISINs, aISIN);
      if ~any(vertcat(myTemp{:}))
        self.ISINs{size(self.ISINs, 2) + 1} = aISIN;
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
        self.Assets.(aISIN){size(self.Assets.(aISIN), 2) + 1} = self.NewTrade(aP, aV);
      else
        % Otherwise, the volume is updated and the time index
        % set to CurrentUpdateIndex
        myIndex = find(myIndex, 1);
        self.Assets.(aISIN){myIndex}.volume = self.Assets.(aISIN){myIndex}.volume + aV;
        self.Assets.(aISIN){myIndex}.index = self.CurrentUpdateIndex;
      end

      % Now we update our copy of the book.
      if aV > 0
        myPrice = 'askLimitPrice';
        myVolume = 'askVolume';
      else
        myPrice = 'bidLimitPrice';
        myVolume = 'bidVolume';
      end

      myIndex = abs(self.DepthHistory.(aISIN){self.CurrentUpdateIndex}.(myPrice) - aP) < 0.01;

      if abs(aV) < self.DepthHistory.(aISIN){self.CurrentUpdateIndex}.(myVolume)
        self.DepthHistory.(aISIN){self.CurrentUpdateIndex}.(myVolume) = self.DepthHistory.(aISIN){self.CurrentUpdateIndex}.(myVolume) - abs(aV);
      else
        self.DepthHistory.(aISIN){self.CurrentUpdateIndex}.(myVolume) = self.DepthHistory.(aISIN){self.CurrentUpdateIndex}.(myVolume)(~myIndex);
        
        self.DepthHistory.(aISIN){self.CurrentUpdateIndex}.(myPrice) = self.DepthHistory.(aISIN){self.CurrentUpdateIndex}.(myPrice)(~myIndex);
      end
    end
  end
end
