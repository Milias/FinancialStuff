classdef AssetManager < handle
  properties
    Assets
    DepthHistory
    ISINs
    CurrentIndex

    ActiveTrades
    CompletedTrades

    InitSize
  end

  methods
    function self = AssetManager(aInitSize) 
      self.InitSize = aInitSize;

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
      self.CurrentIndex = struct('total', 1);
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

    function theData = GetDataFromHistory(self, aISIN, aT)
      % Returns a cell of vectors containing aValue from the last aT depths from aISIN,
      % sorted from newest to oldest. NOTE: here aT counts global ticks, not only ticks
      % counted in self.CurrentIndex.(aISIN).

      if nargin == 2
        theData = self.DepthHistory.(aISIN){self.CurrentIndex.(aISIN)};
      else
        theData = {self.DepthHistory.(aISIN){self.CurrentIndex.(aISIN):-1:self.CurrentIndex.(aISIN)-aT}};
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
      % Copy depths for each ISIN.
      for isin = self.ISINs
        isin = isin{1}; 

        if self.CurrentIndex.total == 1
          self.DepthHistory.(isin){1} = struct('ISIN', isin, 'ticksize', 0.0, 'bidLimitPrice', [], 'bidVolume', [], 'askLimitPrice', [], 'askVolume', []);

        elseif self.CurrentIndex.(isin) > 1
          self.DepthHistory.(isin){self.CurrentIndex.(isin)} = self.DepthHistory.(isin){self.CurrentIndex.(isin)-1};
        end  
      end

      self.CurrentIndex.total = self.CurrentIndex.total + 1;
      self.CurrentIndex.(aDepth.ISIN) = self.CurrentIndex.(aDepth.ISIN) + 1;
      self.DepthHistory.(aDepth.ISIN){self.CurrentIndex.(aDepth.ISIN)} = aDepth;
    end

    function CheckISIN(self, aISIN)
      myTemp = strfind(self.ISINs, aISIN);
      if ~any(vertcat(myTemp{:}))
        self.ISINs{end+1} = aISIN;
        [self.CurrentIndex(:).(aISIN)] = 1;
        [self.Assets(:).(aISIN)] = cell(0);
        [self.DepthHistory(:).(aISIN)] = cell(self.InitSize, 1);
        [self.ActiveTrades(:).(aISIN)] = cell(0);
        [self.CompletedTrades(:).(aISIN)] = cell(0);
      end
    end

    function GenerateNewTrade(self, aISIN, aP, aV)
      self.ActiveTrades.(aISIN){end+1} = struct('price', [aP], 'volume', [aV], 'time', [self.CurrentIndex.total], 'uuid', {char(java.util.UUID.randomUUID)});
      %fprintf('Trade added\n')
      fprintf('Trade (%7s, %5.2f, %3.0f, %s) added.\n', aISIN, mean(aP), sum(aV), self.ActiveTrades.(aISIN){end}.uuid)
    end

    function ArchiveCompletedTrades(self)
      for isin = self.ISINs
        isin = isin{1};

        % Indices of trades with volume zero.
        myIdx = cellfun(@(trade) abs(sum(trade.volume)) < 0.01, self.ActiveTrades.(isin));

        % Updates the CompletedTrades cell array with the new elements from ActiveTrades.
        self.CompletedTrades.(isin)(end+1:end+nnz(myIdx)) = self.ActiveTrades.(isin)(myIdx);

        % Removes completed trades from ActiveTrades.
        self.ActiveTrades.(isin) = self.ActiveTrades.(isin)(~myIdx);
      end
    end

    function UpdateTrade(self, aISIN, aIdx, aP, aV)
      self.ActiveTrades.(aISIN){aIdx}.price(end+1:end+length(aP)) = aP;
      self.ActiveTrades.(aISIN){aIdx}.volume(end+1:end+length(aV)) = aV;
      self.ActiveTrades.(aISIN){aIdx}.time(end+1:end+length(aV)) = self.CurrentIndex.total;
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

      myIndex = abs(self.DepthHistory.(aISIN){self.CurrentIndex.(aISIN)}.(myPrice) - aP) < 0.01;

      if abs(aV) < self.DepthHistory.(aISIN){self.CurrentIndex.(aISIN)}.(myVolume)(myIndex)
        self.DepthHistory.(aISIN){end}.(myVolume)(myIndex) = self.DepthHistory.(aISIN){self.CurrentIndex.(aISIN)}.(myVolume)(myIndex) - abs(aV);
      else
        self.DepthHistory.(aISIN){self.CurrentIndex.(aISIN)}.(myVolume) = self.DepthHistory.(aISIN){self.CurrentIndex.(aISIN)}.(myVolume)(~myIndex);
        self.DepthHistory.(aISIN){self.CurrentIndex.(aISIN)}.(myPrice) = self.DepthHistory.(aISIN){self.CurrentIndex.(aISIN)}.(myPrice)(~myIndex);
      end
    end
  end
end
