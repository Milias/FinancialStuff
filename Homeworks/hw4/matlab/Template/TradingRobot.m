classdef TradingRobot < AutoTrader
  properties
    AssetMgr
    AlgoParams
    Triggers
    TriggersData
    PerfMeasure
  end

  methods
    function self = TradingRobot
      % Initializing the assets manager with the two ISINs.
      self.AssetMgr = AssetManager;
      self.AssetMgr.Init({'DBK_EUR', 'CBK_EUR'});

      % This struct contains basic parameters of the algorithm.
      % max_trading_volume :    maximum amount of shares to hold at any given tick.
      % lookback :              number of past ticks to consider for computations.
      % trigger_params :        several parameters used mainly for triggers.1
      %   dtsmax :              number of ticks we wait before selling stock.
      %   dtbmax :              number of ticks we wait before buying stock.
      %   dthmax :              maximum ticks we hold to the stock.
      %   dssmax :              maximum change of the stock's price before selling.
      %   dsbmax :              change in price before buying.
      self.AlgoParams = struct('max_trading_volume', struct, 'lookback', 100, 'trigger_params', struct('dtsmax', 30, 'dtbmax', 30, 'dthmax', 10, 'dssmax', 0.0, 'dsbmax', 0.0));

      self.AlgoParams.max_trading_volume.DBK_EUR = 10;
      self.AlgoParams.max_trading_volume.CBK_EUR = 10;

      % Here triggers are stored as functions that only take "self" as an argument.
      % TriggersData contains information specific to each function, for bookkeeping.
      % TriggersData.Global is reserved for information concerning more than one trigger.
      self.Triggers = cell(0);
      self.TriggersData = struct;
      self.TriggersData.Global = struct;

      % Placeholder struct to store performance-related stuff.
      self.PerfMeasure = struct;

      % Initialize triggers.
      self.InitTriggers();
    end
    
    function delete(self)
      % Destructor.
      clear self.AssetMgr;
      clear self.AlgoParams;
      clear self.Triggers;
      clear self.TriggersData;
      clear self.PerfMeasure;
    end

    function InitTriggers(self)
      % == TrendTradeTrig ==
      % Trade when the trend changes.
      self.Triggers{end + 1} = 'TrendTradeTrig';
      self.TriggersData.TrendTradeTrig = struct('tick_count_buy', 0, 'tick_count_sell', 0);

      % == ReducePositionTrig ==
      %self.Triggers{end + 1} = 'TradeMatchTrig';
      self.TriggersData.TradeMatchTrig = struct('tick_count', 0);

      % == Detect Trends ==
      % Double exponential smoothing for now with weighted second derivative.
      % TODO: forecasting and back fitting?
      % https://grisha.org/blog/2016/01/29/triple-exponential-smoothing-forecasting/
      % The number of elements on each cell array should be equal to the vector
      % dimensions of the function self.Valuate().
      self.Triggers{end + 1} = 'TrendDetectionTrig';
      self.TriggersData.TrendDetectionTrig = struct;
      self.TriggersData.TrendDetectionTrig.DataLabels = {'askLimitPrice', 'askVolume', 'bidLimitPrice', 'bidVolume'};
      self.TriggersData.TrendDetectionTrig.DataFunctions = {@(data) sum(data.askLimitPrice .* data.askVolume)/sum(data.askVolume), @(data) sum(data.askVolume), @(data) sum(data.bidLimitPrice .* data.bidVolume)/sum(data.bidVolume), @(data) sum(data.bidVolume)};

      for isin = self.AssetMgr.ISINs
        isin = isin{1};
        [self.TriggersData.TrendDetectionTrig(:).(isin)] = struct('c', struct, 'wa', {});
        for label in self.TriggersData.TrendDetectionTrig.DataLabels
          label = label{1};
          [self.TriggersData.TrendDetectionTrig.(isin).c(:).(label)] = [0.05 0.08 0.12];
        end
      end
    end

    function HandleDepthUpdate(self, ~, aDepth)
      % First the new book is stored.
      self.AssetMgr.UpdateDepths(aDepth);
 
      % Run trigger functions.
      self.HandleTriggers();
    end

    function HandleTriggers(self)
      for trig = self.Triggers
        % fprintf('Trig: %s\n', trig{1})
        self.(trig{1})();
      end
    end

    function theIdx = CheckActiveTrades(self, aISIN, aP, aSide)
      theIdx = cell(0);
      for i = 1:length(self.AssetMgr.ActiveTrades.(aISIN))
        trade = self.AssetMgr.ActiveTrades.(aISIN){i};
        if trade.volume(1)*aSide < 0
          continue
        end

        myExpectedProfit = abs(sum(trade.volume)) * aP;
        
        if aSide * myExpectedProfit > aSide * abs(sum(trade.volume .* trade.price))
          theIdx{end+1} = i;
        end
      end
    end

    function FillActiveTrades(self, aISIN, aData)
    end

    function TrendTradeTrig(self)
      for isin = self.AssetMgr.ISINs
        isin = isin{1};

        myData = self.AssetMgr.GetDataFromHistory(isin, {'askLimitPrice', 'askVolume', 'bidLimitPrice', 'bidVolume'}, 0);

        if ~isempty(myData.askLimitPrice) && ~isempty(myData.bidLimitPrice)
          if length(self.TriggersData.TrendDetectionTrig.(isin).wa) > 1

            myWA = self.TriggersData.TrendDetectionTrig.(isin).wa{end};
            myOldWA = self.TriggersData.TrendDetectionTrig.(isin).wa{end-1};

            % Check minimum, d2S > 0 and dS == 0.
            if myWA(1, 3) > 0 && myOldWA(1, 2) * myWA(1, 2) < 0
              % We have to check each entry for a profitable price.
              myIdx = arrayfun(@(p) self.CheckActiveTrades(isin, p), myData.askLimitPrice{1}, 'UniformOutput', false);

              for idx = myIdx
                idx = idx{1};


              end
            end
          end
        end

        if ~any(cellfun(@isempty, myData.askLimitPrice)) && ~any(cellfun(@isempty, myData.bidLimitPrice))
          if length(self.TriggersData.TrendDetectionTrig.(isin).b2_ask) > 1 
            % Check when we are at a minimum (d2V > 0, dV == 0)
            if self.TriggersData.TrendDetectionTrig.(isin).b2_ask(end) > 0 && self.TriggersData.TrendDetectionTrig.(isin).b_ask(end)*self.TriggersData.TrendDetectionTrig.(isin).b_ask(end-1) < 0
              
              myPos = self.AssetMgr.GetISINPosition(isin);
              myVol = min(max(0, self.AlgoParams.max_trading_volume.(isin) - myPos), myData.askVolume{1}(1));
              
              if myVol > 0
                
                % Check if we have any trades that can be improved.
                myIdx = self.CheckActiveTrades(isin, myData.askLimitPrice{1}(1), -1);
                myTradedVolume = 0;

                if ~isempty(myIdx) && ~isempty(self.AssetMgr.ActiveTrades.(isin))
                  myIdx = myIdx{1};
                  trade = self.AssetMgr.ActiveTrades.(isin){myIdx};
                  % Buy enough to complete the trade.
                  myTradePos = abs(sum(self.AssetMgr.ActiveTrades.(isin){myIdx}.volume));
                  myTrades = self.Trade(isin, myData.askLimitPrice{1}(1), min(myTradePos, myVol));
                  fprintf('Before -- Trade: %3d, Pos: %3.0f, Profit: %6.2f\n', myIdx, myTradePos, -sum(trade.price .* trade.volume));

                  if myTrades
                    myTradedVolume = self.ownTrades.side(end-myTrades+1:end) .* self.ownTrades.volume(end-myTrades+1:end);
                    self.AssetMgr.UpdateTrade(isin, myIdx, self.ownTrades.price(end-myTrades+1:end), myTradedVolume);
                    fprintf('After  -- Trade: %3d, Pos: %3.0f, Profit: %6.2f\n', myIdx, sum(self.AssetMgr.ActiveTrades.(isin){myIdx}.volume), -sum(self.AssetMgr.ActiveTrades.(isin){myIdx}.price .* self.AssetMgr.ActiveTrades.(isin){myIdx}.volume));
                    fprintf('TrendTradeTrig - Buy (complete)\n\n');
                  end
                  self.AssetMgr.ArchiveCompletedTrades();
                end
                
                if myVol - myTradedVolume > 0 && isempty(self.AssetMgr.ActiveTrades.(isin))
                  myTrades = self.Trade(isin, myData.askLimitPrice{1}(1), myVol - myTradedVolume);
                  if myTrades
                    self.AssetMgr.GenerateNewTrade(isin, self.ownTrades.price(end), self.ownTrades.side(end)*self.ownTrades.volume(end));
                    fprintf('TrendTradeTrig - Buy (new)\n\n');
                  end
                end
              end
            end
          end

          if length(self.TriggersData.TrendDetectionTrig.(isin).b2_bid) > 1
            if self.TriggersData.TrendDetectionTrig.(isin).b2_bid(end) < 0 && self.TriggersData.TrendDetectionTrig.(isin).b_bid(end)*self.TriggersData.TrendDetectionTrig.(isin).b_bid(end-1) < 0
              myPos = self.AssetMgr.GetISINPosition(isin);
              myVol = min(max(0, self.AlgoParams.max_trading_volume.(isin) + myPos), myData.bidVolume{1}(1));
            
              if myVol > 0
                % Check if we have any trades that can be improved.
                myIdx = self.CheckActiveTrades(isin, myData.bidLimitPrice{1}(1), 1);
                myTradedVolume = 0;

                if ~isempty(myIdx) && ~isempty(self.AssetMgr.ActiveTrades.(isin))
                  myIdx = myIdx{1};
                  trade = self.AssetMgr.ActiveTrades.(isin){myIdx};
                  myTradePos = abs(sum(self.AssetMgr.ActiveTrades.(isi){myIdx}.volume));

                  myTrades = self.Trade(isin, myData.bidLimitPrice{1}(1), -min(myTradePos, myVol));
                  fprintf('Before -- Trade: %3d, Pos: %3.0f, Profit: %6.2f\n', myIdx, myTradePos, -sum(trade.price .* trade.volume));

                  if myTrades
                    % myTradedVolume is negative.
                    myTradedVolume = self.ownTrades.side(end-myTrades+1:end) .* self.ownTrades.volume(end-myTrades+1:end);
                    self.AssetMgr.UpdateTrade(isin, myIdx, self.ownTrades.price(end-myTrades+1:end), myTradedVolume);
                    fprintf('After  -- Trade: %3d, Pos: %3.0f, Profit: %6.2f\n', myIdx, sum(self.AssetMgr.ActiveTrades.(isin){myIdx}.volume), -sum(self.AssetMgr.ActiveTrades.(isin){myIdx}.price .* self.AssetMgr.ActiveTrades.(isin){myIdx}.volume));
                    fprintf('TrendTradeTrig - Sell (complete)\n\n');
                  end
                  self.AssetMgr.ArchiveCompletedTrades();
                end
                
                if myVol + myTradedVolume > 0 && isempty(self.AssetMgr.ActiveTrades.(isin))
                  myTrades = self.Trade(isin, myData.bidLimitPrice{1}(1), - myVol - myTradedVolume);
                  if myTrades
                    self.AssetMgr.GenerateNewTrade(isin, self.ownTrades.price(end), self.ownTrades.side(end)*self.ownTrades.volume(end));
                    fprintf('TrendTradeTrig - Sell (new) \n\n');
                  end
                end
              end
            end
          end
        end
      end
    end

    function TradeMatchTrig(self)
      for isin = self.AssetMgr.ISINs
        isin = isin{1};

        for i = 1:length(self.AssetMgr.ActiveTrades.(isin))
          trade = self.AssetMgr.ActiveTrades.(isin){i};

          myPos = sum(trade.volume);
          if myPos < 0
            myLabels = {'askLimitPrice', 'askVolume'};
          else
            myLabels = {'bidLimitPrice', 'bidVolume'};
          end

          myData = self.AssetMgr.GetDataFromHistory(isin, myLabels, 0);

          if length(myData.(myLabels{1}){1})
            if myData.(myLabels{1}){1}(1) > trade.price(1)
              fprintf('Before -- Trade: %3d, Pos: %3.0f, Profit: %5.2f\n', i, myPos, -sign(myPos)*sum(trade.price .* trade.volume));

              myTrades = self.Trade(isin, myData.(myLabels{1}){1}(1), -min(myPos, myData.(myLabels{2}){1}(1)));

              self.AssetMgr.ActiveTrades.(isin){i}.price = [ self.AssetMgr.ActiveTrades.(isin){i}.price ; self.ownTrades.price(end-myTrades+1:end) ];

              self.AssetMgr.ActiveTrades.(isin){i}.volume = [ self.AssetMgr.ActiveTrades.(isin){i}.volume ; self.ownTrades.side(end-myTrades+1:end).*self.ownTrades.volume(end-myTrades+1:end) ];

              fprintf('After -- Trade: %3d, Pos: %3.0f, Profit: %5.2f\n', i, sum(self.AssetMgr.ActiveTrades.(isin){i}.volume), - sign(myPos) * sum(self.AssetMgr.ActiveTrades.(isin){i}.price .* self.AssetMgr.ActiveTrades.(isin){i}.volume));
            end
          end
        end
      end

      % fprintf('Before. Active: %d, Completed: %d\n', sum(cellfun(@(isin) length(self.AssetMgr.ActiveTrades.(isin)), self.AssetMgr.ISINs)), sum(cellfun(@(isin) length(self.AssetMgr.CompletedTrades.(isin)), self.AssetMgr.ISINs)))
      self.AssetMgr.ArchiveCompletedTrades();
      % fprintf('After. Active: %d, Completed: %d\n', sum(cellfun(@(isin) length(self.AssetMgr.ActiveTrades.(isin)), self.AssetMgr.ISINs)), sum(cellfun(@(isin) length(self.AssetMgr.CompletedTrades.(isin)), self.AssetMgr.ISINs)))
    end 

    function TrendDetectionTrig(self)
      myLabels = self.TriggersData.TrendDetectionTrig.DataLabels;
      myData = self.Valuate();

      for isin = self.AssetMgr.ISINs
        isin = isin{1};

        myCoef = self.TriggersData.TrendDetectionTrig.(isin).c;

        % Old version
        % myData = self.AssetMgr.GetDataFromHistory(isin, myLabels, 0);

        myWA = zeros(length(myLabels), length(myCoef));

        if ~isempty(self.TriggersData.TrendDetectionTrig.(isin).wa)
          myOldWA = self.TriggersData.TrendDetectionTrig.(isin).wa{end};
        end

        for i = 1:length(myLabels)
          label = myLabels{i};

          if ~isnan(myData.(label))
            if length(self.TriggersData.TrendDetectionTrig.(isin).wa) > 1
              myWA(i, 1) = myCoef.(label)(1) * myData.(label){1}(1) + ( 1 - myCoef.(label)(1) ) * ( myOldWA(i, 1) + myOldWA(i, 2) );
              myWA(i, 2) = myCoef.(label)(2) * ( myWA(i, 1) - myOldWA(i, 1) ) + ( 1 - myCoef.(label)(2) ) * myOldWA(i, 2);
              myWA(i, 2) = myCoef.(label)(3) * ( myWA(i, 2) - myOldWA(i, 2) ) + ( 1 - myCoef.(label)(3) ) * myOldWA(i, 3);

            elseif length(self.TriggersData.TrendDetectionTrig.(isin).wa) == 1
              myWA(i, 1) = myData.(label){1}(1);
              myWA(i, 2) = myData.(label){1}(1) - myOldWA(i, 1);
              myWA(i, 3) = myWA(i, 2);

            else
              myWA(i, 1) = myData.(label){1}(1);
              myWA(i, 2) = 0.0;
              myWA(i, 3) = 0.0;
            end
            
            self.TriggersData.TrendDetectionTrig.(isin).wa{end+1} = myWA;
          end
        end
      end
    end

    function theValues = Valuate(self)
      % Computes several values from the book that we will use to compute
      % trends. theValues is a struct with ISIN fields.
      % For now: theValues.ISIN = [askLimitPrice(1), bidLimitPrice(1)]
      % If there are no entries in the book, return NaN.

      theValues = struct;
      myLabels = self.TriggersData.TrendDetectionTrig.DataLabels;
      myFunctions = self.TriggersData.TrendDetectionTrig.DataFunctions;

      for isin = self.AssetMgr.ISINs
        isin = isin{1};
        myData = self.AssetMgr.GetDataFromHistory(isin, myLabels, 0);
        [theValues(:).(isin)] = struct;

        for i = 1:length(myLabels)
          label = myLabels{i};

          [theValues.(isin)(:).(label)] = nan;
          if isempty(myData.(label))
            continue
          else
            theValues.(isin).(label) = myFunctions{i}(myData);
          end
        end
      end
    end

    function theConfirmation = Trade(self, aISIN, aP, aV)
      % Helper function for buying (aV > 0) and selling (aV < 0) stock.
      % Returns whether the order was successful or not.
      myCurrentTrades = length(self.ownTrades.price);
      self.SendNewOrder(aP, abs(aV), sign(aV), {aISIN}, {'IMMEDIATE'}, 0);
      myTradeCount = length(self.ownTrades.price) - myCurrentTrades;
      theConfirmation = myTradeCount;
 
      myLabels = {'askVolume', 'bidVolume'};

      myData = self.AssetMgr.ComputeDataFromHistory(aISIN, myLabels, 0, { @sum, @sum });

      fprintf('Trade info: %7s, %5.2f, %3.0f. MaxVol: %3.0f/%3.0f\n', aISIN, aP, aV, myData.(myLabels{1}){end}, myData.(myLabels{2}){end});
      % Here we iterate over all the trades done (in case aV > first entry's volume),
      % updating our assets and book.
      for i = 1:myTradeCount
        fprintf('Trade: %6.3f, %3.0f - ', self.ownTrades.price(myCurrentTrades+i), sign(aV) * self.ownTrades.volume(myCurrentTrades+i));
        if theConfirmation
          fprintf('Correct.\n');
          self.AssetMgr.UpdateAssets(aISIN, self.ownTrades.price(myCurrentTrades+i), sign(aV) * self.ownTrades.volume(myCurrentTrades+i));
          fprintf('Profit (%7s): %5.2f, total: %5.2f\n', aISIN, self.AssetMgr.GetISINProfit(aISIN), self.AssetMgr.GetTotalProfit());
        end
      end
    end

    function TradeFullStock(self, aISIN, aV)
      % Try to buy/sell the volume aV.
      if aV > 0
        myLabels = {'askLimitPrice', 'askVolume'};
      else
        myLabels = {'bidLimitPrice', 'bidVolume'};
      end

      myData = self.AssetMgr.GetDataFromHistory(aISIN, myLabels, 0);
      if length(myData.(myLabels{1}){end}) && length(myData.(myLabels{2}){end})
        self.Trade(aISIN, myData.(myLabels{1}){end}(end), aV);
      end
    end

    function Unwind(self)
      % Sell sell sell!!
      for isin = self.AssetMgr.ISINs
        isin = isin{1};
        myPos = self.AssetMgr.GetISINPosition(isin);
        self.TradeFullStock(isin, -myPos)
      end

      fprintf('Total updates: %d\n', self.AssetMgr.CurrentIndex.total)
      %self.AssetMgr.delete();
    end
  end
end
