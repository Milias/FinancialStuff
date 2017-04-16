classdef TradingRobot < AutoTrader
  properties
    AssetMgr
    AlgoParams
    Triggers
    TriggersData
    PerfMeasure

    Profiling
  end

  methods
    function self = TradingRobot
      self.Profiling = Profiler;

      self.Profiling.StartTimer('Initialize')
      % This struct contains basic parameters of the algorithm.
      % max_trading_volume :    maximum amount of shares to hold at any given tick.
      % lookback :              number of past ticks to consider for computations.
      % trigger_params :        several parameters used mainly for triggers.1
      %   dtsmax :              number of ticks we wait before selling stock.
      %   dtbmax :              number of ticks we wait before buying stock.
      %   dthmax :              maximum ticks we hold to the stock.
      %   dssmax :              maximum change of the stock's price before selling.
      %   dsbmax :              change in price before buying.
      self.AlgoParams = struct('max_trading_volume', struct, 'lookback', 100, 'trigger_params', struct('dtsmax', 30, 'dtbmax', 30, 'dthmax', 10, 'dssmax', 0.0, 'dsbmax', 0.0), 'init_size', 40000);

      self.AlgoParams.max_trading_volume.DBK_EUR = 10;
      self.AlgoParams.max_trading_volume.CBK_EUR = 10;
      
      % Initializing the assets manager with the two ISINs.
      self.AssetMgr = AssetManager(self.AlgoParams.init_size);
      self.AssetMgr.Init({'DBK_EUR', 'CBK_EUR'});

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
      self.Profiling.StopTimer('Initialize')
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
      % == Detect Trends ==
      % Double exponential smoothing for now with weighted second derivative.
      % TODO: forecasting and back fitting?
      % https://grisha.org/blog/2016/01/29/triple-exponential-smoothing-forecasting/
      % The number of elements on each cell array should be equal to the vector
      % dimensions of the function self.Valuate().
      self.Triggers{end + 1} = 'TrendDetectionTrig';
      self.TriggersData.TrendDetectionTrig = struct;

      %self.TriggersData.TrendDetectionTrig.DataLabels = {'askLimitPrice', 'askVolume', 'bidLimitPrice', 'bidVolume', 'askLimitPrice'};
      self.TriggersData.TrendDetectionTrig.DataLabels = {'askLimitPrice', 'bidLimitPrice', 'askLimitPrice', 'bidLimitPrice'};

      %self.TriggersData.TrendDetectionTrig.DataFunctions = {@(data) sum(data.askLimitPrice .* data.askVolume)/sum(data.askVolume), @(data) sum(data.askVolume), @(data) sum(data.bidLimitPrice .* data.bidVolume)/sum(data.bidVolume), @(data) sum(data.bidVolume), @(data) min(data.askLimitPrice)};
      self.TriggersData.TrendDetectionTrig.DataFunctions = {@(data) sum(data.askLimitPrice .* data.askVolume)/sum(data.askVolume), @(data) sum(data.bidLimitPrice .* data.bidVolume)/sum(data.bidVolume), @(data) min(data.askLimitPrice), @(data) max(data.bidLimitPrice)};
      %self.TriggersData.TrendDetectionTrig.DataFunctions = {@(data) min(data.askLimitPrice), @(data) sum(data.askVolume), @(data) max(data.bidLimitPrice), @(data) sum(data.bidVolume), @(data) min(data.askLimitPrice)};
      %self.TriggersData.TrendDetectionTrig.DataFunctions = {@(data) min(data.askLimitPrice), @(data) min(data.bidLimitPrice), @(data) min(data.askLimitPrice)};

      self.TriggersData.TrendDetectionTrig.wa = cell(self.AlgoParams.init_size, length(self.AssetMgr.ISINs));
      self.TriggersData.TrendDetectionTrig.coef = cell(1, length(self.AssetMgr.ISINs));

      for i = 1:length(self.AssetMgr.ISINs)
        self.TriggersData.TrendDetectionTrig.coef{1,i} = [0.1 0.4 0.8 ; 0.1 0.4 0.8 ; 1.0 0.0 0.0 ; 1.0 0.0 0.0];
        %self.TriggersData.TrendDetectionTrig.coef{1,i} = [0.1 0.12 0.6 ; 0.05 0.08 0.12 ; 0.1 0.12 0.6 ; 0.05 0.08 0.12 ; 1.0 0.0 0.0];
      end

      [self.TriggersData.Global.Valuate.I, self.TriggersData.Global.Valuate.J] = ndgrid(1:length(self.AssetMgr.ISINs), 1:length(self.TriggersData.TrendDetectionTrig.DataLabels));
      
      % == TrendTradeTrig ==
      % Trade when the trend changes.
      self.Triggers{end + 1} = 'TrendTradeTrig';
      self.TriggersData.TrendTradeTrig = struct('tick_count_buy', 0, 'tick_count_sell', 0);

      % == ReducePositionTrig ==
      %self.Triggers{end + 1} = 'TradeMatchTrig';
      self.TriggersData.TradeMatchTrig = struct('tick_count', 0);
    end

    function HandleDepthUpdate(self, ~, aDepth)
      % First the new book is stored.
      self.Profiling.StartTimer('UpdateDepths')
      self.AssetMgr.UpdateDepths(aDepth);
      self.Profiling.StopTimer('UpdateDepths')
 
      % Run trigger functions.
      self.HandleTriggers();
    end

    function HandleTriggers(self)
      for trig = self.Triggers
        % fprintf('Trig: %s\n', trig{1})
        self.Profiling.StartTimer(trig{1});
        self.(trig{1})();
        self.Profiling.StopTimer(trig{1});
      end
    end

    function theProfits = CheckActiveTrades(self, aISIN, aP, aSide)
      % Returns profit from each trade.
      theProfits = zeros(length(self.AssetMgr.ActiveTrades.(aISIN)), 1);

      for i = 1:length(self.AssetMgr.ActiveTrades.(aISIN))
        trade = self.AssetMgr.ActiveTrades.(aISIN){i};
        theProfits(i, :) = (trade.volume(1) * aSide > 0) * max(0, (sum(trade.volume) * aP - sum(trade.volume .* trade.price)));
      end
    end

    function FillActiveTrades(self, aISIN, aData)
    end

    function TrendTradeTrig(self)
      if self.AssetMgr.CurrentIndex.total < 2
        return
      end

      for i = 1:length(self.AssetMgr.ISINs)
        isin = self.AssetMgr.ISINs{i};    

        myData = self.AssetMgr.GetDataFromHistory(isin);

        % WTB
        if ~isempty(myData.askLimitPrice)
          myWA = self.TriggersData.TrendDetectionTrig.wa{self.AssetMgr.CurrentIndex.total, i};
          myOldWA = self.TriggersData.TrendDetectionTrig.wa{self.AssetMgr.CurrentIndex.total-1, i};
          myVol = myData.askVolume;

          % Check minimum, d2S > 0 and dS == 0.
          if myWA(1, 3) > 0 && myOldWA(1, 2) * myWA(1, 2) < 0
            if ~isempty(self.AssetMgr.ActiveTrades.(isin))
              mySide = -1;

              for i = 1:length(myData.askLimitPrice)
                myPrice = myData.askLimitPrice(i);
                 
                % We have to check each entry for a profitable price.
                myProfits = self.CheckActiveTrades(isin, myData.askLimitPrice(i), mySide);
                  
                if ~nnz(myProfits)
                  continue
                end

                % And sort them by column (first dimension).
                [mySortedProfits, mySortedIdx] = sort(myProfits, 'descend');
              
                for j = 1:nnz(myProfits)
                  trade = self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)};
                  myTrades = self.Trade(isin, myPrice, - mySide * min(myVol(i), abs(sum(trade.volume))));

                  if myTrades
                    fprintf('TrendTradeTrig - WTB (complete)\n');
                    fprintf('Trade: %s, Before Pos: %3.0f, ', trade.uuid, sum(trade.volume));
                      
                    myTradedVolume = self.ownTrades.side(end-myTrades+1:end) .* self.ownTrades.volume(end-myTrades+1:end);
                    self.AssetMgr.UpdateTrade(isin, mySortedIdx(j), self.ownTrades.price(end-myTrades+1:end), myTradedVolume);
                    myVol(i) = myVol(i) - abs(sum(myTradedVolume));

                    fprintf('After Pos: %3.0f, Profit: %6.2f\n\n', sum(self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)}.volume), -sum(self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)}.price .* self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)}.volume));
                      
                    self.AssetMgr.ArchiveCompletedTrades();
                  end

                  if myVol(i) == 0
                    break
                  end
                end
              end

              % Create new trades from the cheapest entry in the book, if there is any volume left.
              if myVol(1) > 0 && isempty(self.AssetMgr.ActiveTrades.(isin))
                myTrades = self.Trade(isin, myData.askLimitPrice(1), myVol(1));
                if myTrades
                  fprintf('TrendTradeTrig - WTB (new)\n');
                  self.AssetMgr.GenerateNewTrade(isin, self.ownTrades.price(end-myTrades+1:end), self.ownTrades.side(end-myTrades+1:end).*self.ownTrades.volume(end-myTrades+1:end));
                  fprintf('\n')
                end
              end

            end
          end
        end
        
        % WTS
        if ~isempty(myData.bidLimitPrice)
          myWA = self.TriggersData.TrendDetectionTrig.wa{self.AssetMgr.CurrentIndex.total, i};
          myOldWA = self.TriggersData.TrendDetectionTrig.wa{self.AssetMgr.CurrentIndex.total-1, i};
          myVol = myData.bidVolume;

          % Check maximum, d2S < 0 and dS == 0.
          if myWA(2, 3) < 0 && myOldWA(2, 2) * myWA(2, 2) < 0
            if ~isempty(self.AssetMgr.ActiveTrades.(isin))
              mySide = 1;

              for i = 1:length(myData.bidLimitPrice)
                myPrice = myData.bidLimitPrice(i);
                 
                % We have to check each entry for a profitable price.
                myProfits = self.CheckActiveTrades(isin, myPrice, mySide);

                if ~nnz(myProfits)
                  continue
                end

                % And sort them by column (first dimension).
                [mySortedProfits, mySortedIdx] = sort(myProfits, 'descend');
                  
                for j = 1:nnz(myProfits)
                  trade = self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)};
                  myTrades = self.Trade(isin, myPrice, - mySide * min(myVol(i), abs(sum(trade.volume))));

                  if myTrades
                    fprintf('TrendTradeTrig - WTS (complete)\n');
                    fprintf('Trade: %s, Before Pos: %3.0f, ', trade.uuid, sum(trade.volume));
                     
                    myTradedVolume = self.ownTrades.side(end-myTrades+1:end) .* self.ownTrades.volume(end-myTrades+1:end);                   
                    self.AssetMgr.UpdateTrade(isin, mySortedIdx(j), self.ownTrades.price(end-myTrades+1:end), myTradedVolume);
                    myVol(i) = myVol(i) - abs(sum(myTradedVolume));

                    fprintf('After Pos: %3.0f, Profit: %6.2f\n\n', sum(self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)}.volume), -sum(self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)}.price .* self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)}.volume));
                      
                    self.AssetMgr.ArchiveCompletedTrades();
                  end

                  if myVol(i) == 0
                    break
                  end
                end
              end
            end

            % Create new trades from the cheapest entry in the book, if there is any volume left.
            if myVol(1) > 0 && isempty(self.AssetMgr.ActiveTrades.(isin))
              myTrades = self.Trade(isin, myData.bidLimitPrice(1), -myVol(1));
              if myTrades
                fprintf('TrendTradeTrig - WTS (new)\n');
                self.AssetMgr.GenerateNewTrade(isin, self.ownTrades.price(end-myTrades+1:end), self.ownTrades.side(end-myTrades+1:end).*self.ownTrades.volume(end-myTrades+1:end));
                fprintf('\n')
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

          myData = self.AssetMgr.GetDataFromHistory(isin, 0);

          if length(myData{1}.(myLabels{1}))
            if myData{1}.(myLabels{1})(1) > trade.price(1)
              fprintf('Trade: %s, Before Pos: %3.0f\n', trade.uuid, sum(trade.volume));

              myTrades = self.Trade(isin, myData{1}.(myLabels{1})(1), -min(myPos, myData{1}.(myLabels{2})(1)));

              self.AssetMgr.ActiveTrades.(isin){i}.price = [ self.AssetMgr.ActiveTrades.(isin){i}.price ; self.ownTrades.price(end-myTrades+1:end) ];

              self.AssetMgr.ActiveTrades.(isin){i}.volume = [ self.AssetMgr.ActiveTrades.(isin){i}.volume ; self.ownTrades.side(end-myTrades+1:end).*self.ownTrades.volume(end-myTrades+1:end) ];

              fprintf('After Pos: %3.0f, Profit: %6.2f\n\n', sum(self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)}.volume), -sum(self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)}.price .* self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)}.volume));
            end
          end
        end
      end

      % fprintf('Before. Active: %d, Completed: %d\n', sum(cellfun(@(isin) length(self.AssetMgr.ActiveTrades.(isin)), self.AssetMgr.ISINs)), sum(cellfun(@(isin) length(self.AssetMgr.CompletedTrades.(isin)), self.AssetMgr.ISINs)))
      self.AssetMgr.ArchiveCompletedTrades();
      % fprintf('After. Active: %d, Completed: %d\n', sum(cellfun(@(isin) length(self.AssetMgr.ActiveTrades.(isin)), self.AssetMgr.ISINs)), sum(cellfun(@(isin) length(self.AssetMgr.CompletedTrades.(isin)), self.AssetMgr.ISINs)))
    end 

    function TrendDetectionTrig(self)
      myData = self.Valuate();
      myLabels = self.TriggersData.TrendDetectionTrig.DataLabels;

      for j = 1:length(self.AssetMgr.ISINs)
        isin = self.AssetMgr.ISINs{j};
        myCoef = self.TriggersData.TrendDetectionTrig.coef{1, j};
        
        if self.AssetMgr.CurrentIndex.total > 2
          myOldWA = self.TriggersData.TrendDetectionTrig.wa{self.AssetMgr.CurrentIndex.total-1, j};
        else
          myOldWA = zeros(size(self.TriggersData.TrendDetectionTrig.coef{1, j}) + [0 1]);
        end
        
        myWA = myOldWA;

        for i = 1:length(myLabels)
          if ~isnan(myData(j, i))
            if myOldWA(i, end) > 1
              myWA(i, 1) = myCoef(i, 1) * myData(j, i) + ( 1 - myCoef(i, 1) ) * ( myOldWA(i, 1) + myOldWA(i, 2) );
              myWA(i, 2) = myCoef(i, 2) * ( myWA(i, 1) - myOldWA(i, 1) ) + ( 1 - myCoef(i, 2) ) * myOldWA(i, 2);
              myWA(i, 3) = myCoef(i, 3) * ( myWA(i, 2) - myOldWA(i, 2) ) + ( 1 - myCoef(i, 3) ) * myOldWA(i, 3);
              myWA(i, end) = myOldWA(i, end) + 1;

            elseif myOldWA(i, end) == 1
              myWA(i, 1) = myData(j, i);
              myWA(i, 2) = myWA(i, 1) - myOldWA(i, 1);
              myWA(i, 3) = 0.0; 
              myWA(i, end) = myOldWA(i, end) + 1;

            else
              myWA(i, 1) = myData(j, i);
              myWA(i, 2) = 0.0;
              myWA(i, 3) = 0.0;
              myWA(i, end) = myOldWA(i, end) + 1;
            end 
          end
        end
        self.TriggersData.TrendDetectionTrig.wa{self.AssetMgr.CurrentIndex.total, j} = myWA;
      end
    end

    function theValues = Valuate(self)
      % Computes several values from the book that we will use to calculate trends.
      % If there are no entries in the book, return NaN.

      self.Profiling.StartTimer('Valuate')
      
      myData = cellfun(@(isin) self.AssetMgr.GetDataFromHistory(isin), self.AssetMgr.ISINs, 'UniformOutput', false);

      theValues = arrayfun(@(i, j) iff(isempty(myData{i}.(self.TriggersData.TrendDetectionTrig.DataLabels{j})), nan,  self.TriggersData.TrendDetectionTrig.DataFunctions{j}(myData{i})), self.TriggersData.Global.Valuate.I, self.TriggersData.Global.Valuate.J);
      
      self.Profiling.StopTimer('Valuate')
    end

    function theConfirmation = Trade(self, aISIN, aP, aV)
      % Helper function for buying (aV > 0) and selling (aV < 0) stock.
      % Returns whether the order was successful or not.
      self.Profiling.StartTimer('Trade')
      myCurrentTrades = length(self.ownTrades.price);
      self.SendNewOrder(aP, abs(aV), sign(aV), {aISIN}, {'IMMEDIATE'}, 0);
      theConfirmation = length(self.ownTrades.price) - myCurrentTrades;
 
      myData = self.AssetMgr.GetDataFromHistory(aISIN);

      fprintf('Trade info: %7s, %5.2f, %3.0f. MaxVol: %3.0f/%3.0f\n', aISIN, aP, aV, sum(myData.askVolume), sum(myData.bidVolume));
      % Here we iterate over all the trades done (in case aV > first entry's volume),
      % updating our assets and book.
      for i = 1:theConfirmation
        fprintf('Trade: %6.2f, %3.0f - Correct\n', self.ownTrades.price(myCurrentTrades+i), sign(aV) * self.ownTrades.volume(myCurrentTrades+i));
        self.AssetMgr.UpdateAssets(aISIN, self.ownTrades.price(myCurrentTrades+i), sign(aV) * self.ownTrades.volume(myCurrentTrades+i));
        fprintf('Profit (%7s): %6.2f, total: %6.2f\n', aISIN, self.AssetMgr.GetISINProfit(aISIN), self.AssetMgr.GetTotalProfit());
      end
      self.Profiling.StopTimer('Trade')
    end

    function TradeFullStock(self, aISIN, aV)
      % Try to buy/sell the volume aV.
      if aV > 0
        myLabels = {'askLimitPrice', 'askVolume'};
      else
        myLabels = {'bidLimitPrice', 'bidVolume'};
      end

      myData = self.AssetMgr.GetDataFromHistory(aISIN);
      if ~isempty(myData.(myLabels{1}))
        self.Trade(aISIN, myData.(myLabels{1})(end), aV);
      end
    end

    function Unwind(self)
      % Sell sell sell!!
      for isin = self.AssetMgr.ISINs
        isin = isin{1};
        myPos = self.AssetMgr.GetISINPosition(isin);
        self.TradeFullStock(isin, -myPos)
      end

      fprintf('Total updates: %d\n\n', self.AssetMgr.CurrentIndex.total)
      self.Profiling.PrintAll()
      fprintf('\n')
    end
  end
end

function result = iff(condition,trueResult,falseResult)
  if condition
    result = trueResult;
  else
    result = falseResult;
  end
end
