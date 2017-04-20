isin = 'DBK_EUR';
isin_n = 1;

trades_t1 = cellfun(@(trade) trade.time(:)', myTradingRobot.AssetMgr.CompletedTrades.(isin), 'UniformOutput', false);
trades_t2 = cellfun(@(trade) trade.time(:)', myTradingRobot.AssetMgr.ActiveTrades.(isin), 'UniformOutput', false);
trades_t = [trades_t1{:} trades_t2{:}];

trades_p1 = cellfun(@(trade) trade.price(:)', myTradingRobot.AssetMgr.CompletedTrades.(isin), 'UniformOutput', false);
trades_p2 = cellfun(@(trade) trade.price(:)', myTradingRobot.AssetMgr.ActiveTrades.(isin), 'UniformOutput', false);
trades_p = [trades_p1{:} trades_p2{:}];

trades_v1 = cellfun(@(trade) trade.volume(:)', myTradingRobot.AssetMgr.CompletedTrades.(isin), 'UniformOutput', false);
trades_v2 = cellfun(@(trade) trade.volume(:)', myTradingRobot.AssetMgr.ActiveTrades.(isin), 'UniformOutput', false);
trades_v = [trades_v1{:} trades_v2{:}];
trades_v = arrayfun(@(x) int2str(x), trades_v, 'UniformOutput', false);

trades_s1 = cellfun(@(trade) trade.volume(:)'>0, myTradingRobot.AssetMgr.CompletedTrades.(isin), 'UniformOutput', false);
trades_s2 = cellfun(@(trade) trade.volume(:)'>0, myTradingRobot.AssetMgr.ActiveTrades.(isin), 'UniformOutput', false);
trades_s = [trades_s1{:} trades_s2{:}];

nonzero = cellfun(@(x) ~isempty(x), {myTradingRobot.TriggersData.TrendDetectionTrig.wa{:, isin_n}});
vals = {myTradingRobot.TriggersData.TrendDetectionTrig.wa{nonzero, isin_n}};

nonzero2 = cellfun(@(x) ~isempty(x), {myTradingRobot.TriggersData.TrendDetectionTrig.wa{:, 2}});
vals2 = {myTradingRobot.TriggersData.TrendDetectionTrig.wa{nonzero, 2}};

ask_level = cellfun(@(wa) wa(1, 1), vals);
ask_real = cellfun(@(wa) wa(3, 1), vals);
bid_level = cellfun(@(wa) wa(2, 1), vals);
bid_real = cellfun(@(wa) wa(4, 1), vals);

ask_level2 = cellfun(@(wa) wa(1, 1), vals2);
ask_real2 = cellfun(@(wa) wa(3, 1), vals2);
bid_level2 = cellfun(@(wa) wa(2, 1), vals2);
bid_real2 = cellfun(@(wa) wa(4, 1), vals2);

xmin = find(ask_level>0, 1);
xmin2 = find(ask_level2>0, 1);
final_xmin = max(xmin, xmin2);

n_window = 700;
T = 1:2500;

lags = arrayfun(@(t) CalcLag(ask_real(final_xmin+t:final_xmin+t+n_window), ask_real2(final_xmin+t:final_xmin+t+n_window), n_window), T);
notnan = ~isnan(lags);

plot(T(notnan)+final_xmin, (lags(notnan)>0), '.', 'MarkerSize', 30)
hold on
plot(T(notnan)+final_xmin,ask_real(T(notnan)+final_xmin)-mean(ask_real), '-', 'LineWidth', 2, 'Color', 'red')
plot(T(notnan)+final_xmin,ask_real2(T(notnan)+final_xmin)-mean(ask_real2), '-', 'LineWidth', 2, 'Color', 'blue')
hold off

ask_level = ask_level(xmin:end);
ask_real = ask_real(xmin:end);
bid_level = bid_level(xmin:end);
bid_real = bid_real(xmin:end);

ask_level2 = ask_level2(xmin2:end);
ask_real2 = ask_real2(xmin2:end);
bid_level2 = bid_level2(xmin2:end);
bid_real2 = bid_real2(xmin2:end);

trades_t_rep = arrayfun(@(x) nnz(trades_t(x)==trades_t(1:x-1)), 1:length(trades_t));

%{
plot(ask_level, '-', 'LineWidth', 1, 'Color', 'red')
hold on
plot(ask_real, '--', 'LineWidth', 1, 'Color', 'red')
plot(bid_level, '-', 'LineWidth', 1, 'Color', 'blue')
plot(bid_real, '--', 'LineWidth', 1, 'Color', 'blue')
plot(trades_t(trades_s)-xmin, trades_p(trades_s), '.', 'MarkerSize', 30, 'Color', 'red')
plot(trades_t(~trades_s)-xmin, trades_p(~trades_s), '.', 'MarkerSize', 30, 'Color', 'blue')
text(trades_t-xmin, trades_p + 0.025 + (0.05*trades_t_rep), trades_v, 'FontSize', 16, 'Clipping', 'on')
hold off
%}

function theArgMax = argmax(a)
  [~, theArgMax] = max(a);
end

function theResult = iff(aC, aT, aF)
  if aC
    theResult = aT;
  else
    theResult = aF;
  end
end

function theLag = CalcLag(x, y, n_window)
  [xcf, lags, bounds] = crosscorr(x, y, n_window, 3);
  [argVal, argMax] = max(xcf);
  if abs(argVal) < bounds(1)
    theLag = nan;
    return
  else
    theLag = lags(argMax);
  end
end