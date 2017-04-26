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
      % Initial values of the cell arrays where the data is stored.
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

      % Initialize ISIN data for several variables.
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

    % Computes the total position for a given ISIN.
    function theVolume = GetISINPosition(self, aISIN)
      theVolume = sum(cellfun(@(asset) asset.volume, self.Assets.(aISIN)));
    end

    % Computes the total position from every ISIN.
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
        theData = {self.DepthHistory.(aISIN){self.CurrentIndex.(aISIN):-1:max(1, self.CurrentIndex.(aISIN)-aT)}};
      end
    end

    % Computes the total profit adding all ISINs.
    function theProfit = GetTotalProfit(self)
      theProfit = -sum(cellfun(@(isin) sum(cellfun(@(asset) asset.price .* asset.volume, self.Assets.(isin))), self.ISINs));
    end

    % Computes the profit made from one given ISIN.
    function theProfit = GetISINProfit(self, aISIN)
      theProfit = -sum(cellfun(@(asset) asset.price .* asset.volume, self.Assets.(aISIN))); 
    end

    % Computes the profit from a given ISIN considering only completed trades.
    function theProfit = GetComplProfit(self, aISIN)
      theProfit = -sum(cellfun(@(trade) sum(trade.volume .* trade.price), self.CompletedTrades.(aISIN)));
    end

    % Computes the market position for a given ISIN, returning only
    % positive or negative contributions.
    function thePosition = GetActivePosition(self, aISIN, aSide)
      thePosition = sum(cellfun(@(trade) IfElseScalar(trade.volume*aSide > 0, sum(trade.volume), 0), self.ActiveTrades.(aISIN)));
    end

    % Copy the new book to storage.
    function UpdateDepths(self, aDepth)
      % Copy depths for each ISIN.
      for isin = self.ISINs
        isin = isin{1}; 

        if self.CurrentIndex.total == 1
          % Initializing new books in the first update.
          self.DepthHistory.(isin){1} = struct('ISIN', isin, 'ticksize', 0.0, 'bidLimitPrice', [], 'bidVolume', [], 'askLimitPrice', [], 'askVolume', []);

        elseif self.CurrentIndex.(isin) > 1
          % Always copy the previous book for each ISIN, even if it hasn't been modified.
          self.DepthHistory.(isin){self.CurrentIndex.(isin)} = self.DepthHistory.(isin){self.CurrentIndex.(isin)-1};
        end  
      end

      % Here the book update counter gets increased and the new book stored.
      self.CurrentIndex.total = self.CurrentIndex.total + 1;
      self.CurrentIndex.(aDepth.ISIN) = self.CurrentIndex.(aDepth.ISIN) + 1;
      self.DepthHistory.(aDepth.ISIN){self.CurrentIndex.(aDepth.ISIN)} = aDepth;
    end

    % Helper function to initialize all the variables needed for each ISIN.
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

    % Function to create a new trade, this is a structure containing three fields: prices, volumes and times.
    % Each field is an array of the same length, and it contains all the transactions related to it.
    function GenerateNewTrade(self, aISIN, aP, aV)
      self.ActiveTrades.(aISIN){end+1} = struct('price', [aP], 'volume', [aV], 'time', arrayfun(@(p) self.CurrentIndex.total, aP), 'uuid', {char(java.util.UUID.randomUUID)});
      %fprintf('Trade added\n')
      fprintf('Trade (%7s, %5.2f, %3.0f, %s) added.\n', aISIN, mean(aP), sum(aV), self.ActiveTrades.(aISIN){end}.uuid)
    end

    % Helper function to print how many outstanding trades there are, and their absolute position.
    function PrintActivePosition(self)
      cellfun(@(isin) fprintf('[%7s] Active: %3d -- Position: %3.0f/%3.0f\n', isin, length(self.ActiveTrades.(isin)), self.GetActivePosition(isin, 1), self.GetActivePosition(isin, -1)), self.ISINs);
    end

    % Function to move trades with sum(trade.volume) = 0 from the cell array self.ActiveTrades to
    % self.CompletedTrades. It's called after every function that adds a transaction to a trade.
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

    % Function to add a new transaction to a given trade.
    function UpdateTrade(self, aISIN, aIdx, aP, aV)
      self.ActiveTrades.(aISIN){aIdx}.price(end+1:end+length(aP)) = aP;
      self.ActiveTrades.(aISIN){aIdx}.volume(end+1:end+length(aV)) = aV;
      self.ActiveTrades.(aISIN){aIdx}.time(end+1:end+length(aV)) = self.CurrentIndex.total;
    end

    % Original function to store transactions in bulk, doing more or less the same
    % as robot.ownTrades. It also updates the book accordingly.
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

      % myIndex is the index of the entry in the book we want to update.
      myIndex = abs(self.DepthHistory.(aISIN){self.CurrentIndex.(aISIN)}.(myPrice) - aP) < 0.01;

      if abs(aV) < self.DepthHistory.(aISIN){self.CurrentIndex.(aISIN)}.(myVolume)(myIndex)
        % If the entry doesn't disappear, we only update it.
        self.DepthHistory.(aISIN){self.CurrentIndex.(aISIN)}.(myVolume)(myIndex) = self.DepthHistory.(aISIN){self.CurrentIndex.(aISIN)}.(myVolume)(myIndex) - abs(aV);
      else
        % Otherwise, the whole book gets updated removing that entry.
        self.DepthHistory.(aISIN){self.CurrentIndex.(aISIN)}.(myVolume) = self.DepthHistory.(aISIN){self.CurrentIndex.(aISIN)}.(myVolume)(~myIndex);
        self.DepthHistory.(aISIN){self.CurrentIndex.(aISIN)}.(myPrice) = self.DepthHistory.(aISIN){self.CurrentIndex.(aISIN)}.(myPrice)(~myIndex);
      end
    end
  end
end
