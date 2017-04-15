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
      % == Detect Trends ==
      % Double exponential smoothing for now with weighted second derivative.
      % TODO: forecasting and back fitting?
      % https://grisha.org/blog/2016/01/29/triple-exponential-smoothing-forecasting/
      % The number of elements on each cell array should be equal to the vector
      % dimensions of the function self.Valuate().
      self.Triggers{end + 1} = 'TrendDetectionTrig';
      self.TriggersData.TrendDetectionTrig = struct;
      self.TriggersData.TrendDetectionTrig.DataLabels = {'askLimitPrice', 'askVolume', 'bidLimitPrice', 'bidVolume', 'askLimitPrice'};
      %self.TriggersData.TrendDetectionTrig.DataFunctions = {@(data) sum(data.askLimitPrice{1} .* data.askVolume{1})/sum(data.askVolume{1}), @(data) sum(data.askVolume{1}), @(data) sum(data.bidLimitPrice{1} .* data.bidVolume{1})/sum(data.bidVolume{1}), @(data) sum(data.bidVolume{1})};
      self.TriggersData.TrendDetectionTrig.DataFunctions = {@(data) data.askLimitPrice{1}(1), @(data) sum(data.askVolume{1}), @(data) data.bidLimitPrice{1}(1), @(data) sum(data.bidVolume{1}), @(data) data.askLimitPrice{1}(1)};

      for isin = self.AssetMgr.ISINs
        isin = isin{1};
        [self.TriggersData.TrendDetectionTrig(:).(isin)] = struct;
        self.TriggersData.TrendDetectionTrig.(isin).coef = {[0.1 0.12 0.6 ; 0.05 0.08 0.12 ; 0.05 0.08 0.12 ; 0.05 0.08 0.12 ; 1.0 0.0 0.0]};
        self.TriggersData.TrendDetectionTrig.(isin).wa = {};
      end
      
      % == TrendTradeTrig ==
      % Trade when the trend changes.
      %self.Triggers{end + 1} = 'TrendTradeTrig';
      self.TriggersData.TrendTradeTrig = struct('tick_count_buy', 0, 'tick_count_sell', 0);

      % == ReducePositionTrig ==
      %self.Triggers{end + 1} = 'TradeMatchTrig';
      self.TriggersData.TradeMatchTrig = struct('tick_count', 0);
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

    function theProfits = CheckActiveTrades(self, aISIN, aP, aSide)
      % Returns profit from each trade.
      theProfits = zeros(length(self.AssetMgr.ActiveTrades.(aISIN)), 1);

      for i = 1:length(self.AssetMgr.ActiveTrades.(aISIN))
        trade = self.AssetMgr.ActiveTrades.(aISIN){i};
        theProfits(i, :) = (trade.volume(1) * aSide > 0) * max(0, aSide * (sum(trade.volume) * aP - sum(trade.volume .* trade.price)));
      end
    end

    function FillActiveTrades(self, aISIN, aData)
    end

    function TrendTradeTrig(self)
      for isin = self.AssetMgr.ISINs
        isin = isin{1};

        myData = self.AssetMgr.GetDataFromHistory(isin, {'askLimitPrice', 'askVolume', 'bidLimitPrice', 'bidVolume'}, 0);

        % WTB
        if ~isempty(myData.askLimitPrice{1})
          if length(self.TriggersData.TrendDetectionTrig.(isin).wa) > 1

            myWA = self.TriggersData.TrendDetectionTrig.(isin).wa{end};
            myOldWA = self.TriggersData.TrendDetectionTrig.(isin).wa{end-1};

            % Check minimum, d2S > 0 and dS == 0.
            if myWA(1, 3) > 0 && myOldWA(1, 2) * myWA(1, 2) < 0
              if ~isempty(self.AssetMgr.ActiveTrades.(aISIN))
                mySide = -1;
                myVol = myData.askVolume{1};

                for i = 1:length(myData.askLimitPrice{1})
                  myPrice = myData.askLimitPrice{1}(i);
                 
                  % We have to check each entry for a profitable price.
                  myProfits = self.CheckActiveTrades(isin, myData.askLimitPrice{1}(i), mySide);
                  
                  if ~nnz(myProfits)
                    continue
                  end

                  % And sort them by column (first dimension).
                  [mySortedProfits, mySortedIdx] = sort(myProfts, 'descending');
              
                  for j = 1:nnz(theProfits)
                    trade = self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)};
                    myTrades = self.Trade(isin, myPrice, -mySide * min(myVol(i), abs(sum(trade.volume))));

                    if myTrades
                      fprintf('TrendTradeTrig - WTB (complete)\n');
                      fprintf('Before -- Trade: %s, Pos: %3.0f, Profit: %6.2f\n', trade.uuid, sum(trade.volume), -sum(trade.price .* trade.volume));
                      fprintf('After  -- Trade: %s, Pos: %3.0f, Profit: %6.2f\n\n', trade.uuid, sum(self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)}.volume), -sum(self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)}.price .* self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)}.volume));
                      
                      myTradedVolume = self.ownTrades.side(end-myTrades+1:end) .* self.ownTrades.volume(end-myTrades+1:end);                   
                      self.AssetMgr.UpdateTrade(isin, mySortedIdx(j, i), self.ownTrades.price(end-myTrades+1:end), myTradedVolume);
                      myVol(i) = myVol(i) - myTradedVolume;
                      
                      self.AssetMgr.ArchiveCompletedTrades(i);
                    end

                    if myVol(i) <= 0
                      break
                    end
                  end
                end
              end

              % Create new trades from the cheapest entry in the book, if there is any volume left.
              if myVol(1) > 0 && isempty(self.AssetMgr.ActiveTrades.(isin))
                myTrades = self.Trade(isin, myData.askLimitPrice{1}(1), myVol(1));
                for i = 1:myTrades
                  fprintf('TrendTradeTrig - WTB (new)\n');
                  self.AssetMgr.GenerateNewTrade(isin, self.ownTrades.price(end-i+1:end), self.ownTrades.side(end-i+1:end).*self.ownTrades.volume(end-i+1:end));
                  fprintf('\n')
                end
              end

            end
          end
        end
        
        % WTS
        if ~isempty(myData.bidLimitPrice{1})
          if length(self.TriggersData.TrendDetectionTrig.(isin).wa) > 1

            myWA = self.TriggersData.TrendDetectionTrig.(isin).wa{end};
            myOldWA = self.TriggersData.TrendDetectionTrig.(isin).wa{end-1};

            % Check maximum, d2S < 0 and dS == 0.
            if myWA(3, 3) < 0 && myOldWA(3, 2) * myWA(3, 2) < 0
              if ~isempty(self.AssetMgr.ActiveTrades.(aISIN))
                mySide = 1;
                myVol = myData.bidVolume{1};

                for i = 1:length(myData.bidLimitPrice{1})
                  myPrice = myData.bidLimitPrice{1}(i);
                 
                  % We have to check each entry for a profitable price.
                  myProfits = self.CheckActiveTrades(isin, myPrice, mySide);

                  if ~nnz(myProfits)
                    continue
                  end

                  % And sort them by column (first dimension).
                  [mySortedProfits, mySortedIdx] = sort(myProfts, 'descending');
              
                  for j = 1:nnz(theProfits)
                    trade = self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)};
                    myTrades = self.Trade(isin, myPrice, -mySide * min(myVol(i), abs(sum(trade.volume))));

                    if myTrades
                      fprintf('TrendTradeTrig - WTS (complete)\n\n');
                      fprintf('Before -- Trade: %s, Pos: %3.0f, Profit: %6.2f\n', trade.uuid, sum(trade.volume), -sum(trade.price .* trade.volume));
                      fprintf('After  -- Trade: %s, Pos: %3.0f, Profit: %6.2f\n', trade.uuid, sum(self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)}.volume), -sum(self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)}.price .* self.AssetMgr.ActiveTrades.(isin){mySortedIdx(j)}.volume));
                     
                      myTradedVolume = self.ownTrades.side(end-myTrades+1:end) .* self.ownTrades.volume(end-myTrades+1:end);                   
                      self.AssetMgr.UpdateTrade(isin, mySortedIdx(j), self.ownTrades.price(end-myTrades+1:end), myTradedVolume);
                      myVol(i) = myVol(i) - myTradedVolume;
                      
                      self.AssetMgr.ArchiveCompletedTrades(i);
                    end

                    if myVol(i) == 0
                      break
                    end
                  end
                end
              end

              % Create new trades from the cheapest entry in the book, if there is any volume left.
              if myVol(1) > 0 && isempty(self.AssetMgr.ActiveTrades.(isin))
                myTrades = self.Trade(isin, myData.bidLimitPrice{1}(1), myVol(1));
                for i = 1:myTrades
                  fprintf('TrendTradeTrig - WTS (new)\n');
                  self.AssetMgr.GenerateNewTrade(isin, self.ownTrades.price(end-i+1:end), self.ownTrades.side(end-i+1:end).*self.ownTrades.volume(end-i+1:end));
                  fprintf('\n')
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
        myCoef = self.TriggersData.TrendDetectionTrig.(isin).coef{end};

        % Old version
        % myData = self.AssetMgr.GetDataFromHistory(isin, myLabels, 0);

        myWA = zeros(length(myLabels), size(myCoef, 2) + 1);

        if ~isempty(self.TriggersData.TrendDetectionTrig.(isin).wa)
          myOldWA = self.TriggersData.TrendDetectionTrig.(isin).wa{end};
        else
          myOldWA = myWA;
        end

        for i = 1:length(myLabels)
          label = myLabels{i};

          if ~isnan(myData.(isin).(label))
            if myOldWA(i, end) > 1
              myWA(i, 1) = myCoef(i, 1) * myData.(isin).(label) + ( 1 - myCoef(i, 1) ) * ( myOldWA(i, 1) + myOldWA(i, 2) );
              myWA(i, 2) = myCoef(i, 2) * ( myWA(i, 1) - myOldWA(i, 1) ) + ( 1 - myCoef(i, 2) ) * myOldWA(i, 2);
              myWA(i, 3) = myCoef(i, 3) * ( myWA(i, 2) - myOldWA(i, 2) ) + ( 1 - myCoef(i, 3) ) * myOldWA(i, 3);
              myWA(i, 4) = myOldWA(i, 4) + 1;

            elseif myOldWA(i, end) == 1
              myWA(i, 1) = myData.(isin).(label);
              myWA(i, 2) = myData.(isin).(label) - myOldWA(i, 1);
              myWA(i, 3) = 0.0; 
              myWA(i, 4) = 2;

            else
              myWA(i, 1) = myData.(isin).(label);
              myWA(i, 2) = 0.0;
              myWA(i, 3) = 0.0;
              myWA(i, 4) = 1;
            end 
          else
            myWA(i, :) = myOldWA(i, :); 
          end
        end
        self.TriggersData.TrendDetectionTrig.(isin).wa{end+1} = myWA;
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

          if isempty(myData.(label){1})
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
