classdef AssetManager < handle
  properties
    Assets
    DepthHistory
    ISINs
    CurrentIndex

    ActiveTrades
    CompletedTrades
  end

  methods
    function self = AssetManager 
      % Struct where we store the price and volume of our assets.
      % It's structure is self.Assets.ISIN = {struct('price', 0.0, 'volume', 0)}.
      self.Assets = struct;

      % Struct where trades are stored.
      self.ActiveTrades = struct;
      self.CompletedTrades = struct;
      
      % Struct of vectors containing depths for each ISIN.
      % Structure: self.DepthHistory.ISIN = {}.
      self.DepthHistory = struct;
      
      % Vector of stored ISINs.
      self.ISINs = cell(0);
    
      % Keeping track of how many book updates we've received.
      % Total,  and one index per ISIN.
      self.CurrentIndex = struct('total', 0);
    end

    function Init(self, aISINs)
      if nargin == 1
        aISINs = {};
      end

      for i = 1:length(aISINs)
        self.CheckISIN(aISINs{i})
      end
    end

    function delete(self)
      % Destructor.
      clear self.Assets;
      clear self.DepthHistory;
      clear self.ISINs;
      clear self.CurrentIndex;

      clear self.ActiveTrades;
      clear self.CompletedTrades;
    end

    function theVolume = GetISINPosition(self, aISIN)
      theVolume = sum(cellfun(@(asset) asset.volume, self.Assets.(aISIN)));
    end

    function theVolume = GetTotalPosition(self)
      theVolume = sum(cellfun(@(isin) sum(cellfun(@(asset) asset.volume, self.Assets.(isin))), self.ISINs));
    end

    function theData = GetDataFromHistory(self, aISIN, aValues, aT)
      % Returns a cell of vectors containing aValue from the last aT depths from aISIN,
      % sorted from newest to oldest. NOTE: here aT counts global ticks, not only ticks
      % counted in self.CurrentIndex.(aISIN).
      theData = struct;
      
      for myVal = aValues
        myVal = myVal{1};
        [theData(:).(myVal)] = cellfun(@(depth) depth.(myVal), {self.DepthHistory.(aISIN){self.CurrentIndex.total:-1:max(1, self.CurrentIndex.total - aT)}}, 'UniformOutput', false);
      end
    end

    function theData = ComputeDataFromHistory(self, aISIN, aValues, aT, aFunc)
      % Computes values using the history.
      theData = self.GetDataFromHistory(aISIN, aValues, aT);

      for i = 1:length(aValues)
        theData.(aValues{i}) = { cellfun(@(x) aFunc{i}(x), theData.(aValues{i})) };
      end
    end

    function theProfit = GetTotalProfit(self)
      theProfit = -sum(cellfun(@(isin) sum(cellfun(@(asset) asset.price .* asset.volume, self.Assets.(isin))), self.ISINs));
    end

    function theProfit = GetISINProfit(self, aISIN)
      theProfit = -sum(cellfun(@(asset) asset.price .* asset.volume, self.Assets.(aISIN))); 
    end

    function theProfit = GetComplProfit(self, aISIN)
      theProfit = sum(cellfun(@(trade) sum(trade.price), self.CompletedTrades.(aISIN)));
    end

    function UpdateDepths(self, aDepth)
      % Increasing the amount of book updates we have received.
      self.CurrentIndex.total = self.CurrentIndex.total + 1;
      self.CurrentIndex.(aDepth.ISIN) = self.CurrentIndex.(aDepth.ISIN) + 1;

      % Copy depths for each ISIN.
      for myISIN = self.ISINs
        myISIN = myISIN{1}; 
        if length(self.DepthHistory.(myISIN))
          self.DepthHistory.(myISIN){end+1} = self.DepthHistory.(myISIN){end};
        else
          self.DepthHistory.(myISIN){1} = struct('ISIN', myISIN, 'ticksize', 0.0, 'bidLimitPrice', [], 'bidVolume', [], 'askLimitPrice', [], 'askVolume', []);
        end
      end

      if length(self.DepthHistory.(aDepth.ISIN))
        self.DepthHistory.(aDepth.ISIN){end} = aDepth;
      else 
        self.DepthHistory.(aDepth.ISIN){1} = aDepth;
      end
    end

    function CheckISIN(self, aISIN)
      myTemp = strfind(self.ISINs, aISIN);
      if ~any(vertcat(myTemp{:}))
        self.ISINs{end+1} = aISIN;
        [self.CurrentIndex(:).(aISIN)] = 0;
        [self.Assets(:).(aISIN)] = cell(0);
        [self.DepthHistory(:).(aISIN)] = cell(0);
        [self.ActiveTrades(:).(aISIN)] = cell(0);
        [self.CompletedTrades(:).(aISIN)] = cell(0);
      end
    end

    function GenerateNewTrade(self, aISIN, aP, aV)
      self.ActiveTrades.(aISIN){length(self.ActiveTrades.(aISIN)) + 1} = struct('price', [aP], 'volume', [aV], 'time', [self.CurrentIndex.total]);
      fprintf('Trade %d (%7s) added.\n', length(self.ActiveTrades.(aISIN)), aISIN)
    end

    function ArchiveCompletedTrades(self)
      for isin = self.ISINs
        isin = isin{1};

        % Indices of trades with volume zero.
        myIdx = cellfun(@(trade) abs(sum(trade.volume)) < 0.01, self.ActiveTrades.(isin));

        % Updates the CompletedTrades cell array with the new elements from ActiveTrades.
        self.CompletedTrades.(isin)(length(self.CompletedTrades.(isin))+1:length(self.CompletedTrades.(isin))+nnz(myIdx)) = self.ActiveTrades.(isin)(myIdx);

        % Removes completed trades from ActiveTrades.
        self.ActiveTrades.(isin) = self.ActiveTrades.(isin)(~myIdx);
      end
    end

    function UpdateAssets(self, aISIN, aP, aV)
      self.Assets.(aISIN){length(self.Assets.(aISIN)) + 1} = struct('price', aP, 'volume', aV);

      for isin = self.ISINs
        isin = isin{1};
        fprintf('ISIN: %7s, position: %3.0f\n', isin, self.GetISINPosition(isin))
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
