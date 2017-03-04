#!/bin/python
# -*- coding: utf-8 -*-
from numpy import *
import matplotlib.pyplot as plt

def p_oP_plot():
  X = loadtxt('../data/P.txt', delimiter=',')
  Y = loadtxt('../data/oP.txt', delimiter=',')

  plt.plot(X, Y, 'r-')
  plt.axis([0.0, 1.0, 0.0, amax(Y)])

  plt.title('Expected profit - risky approach')
  plt.xlabel('P / Risk')
  plt.ylabel(r'$\langle oP \rangle_r$ / Expected profit')

  plt.savefig('../tex/graphs/P-oP.eps')
  plt.clf()

def p_profit_plot():
  X = loadtxt('../data/P.txt', delimiter=',')
  Y = 100*loadtxt('../data/profit.txt', delimiter=',')

  plt.plot(X, Y, 'r-')
  plt.axis([0.0, 1.0, 100, amax(Y)])

  plt.title('Expected profit% - risky approach')
  plt.xlabel('P / Risk')
  plt.ylabel(r'$1+\frac{\langle oP \rangle_r}{aE}$ / Expected profit%')

  plt.savefig('../tex/graphs/P-Profit.eps')
  plt.clf()

def share_value_hist():
  X = loadtxt('../data/rw-hist-edges.txt', delimiter=',')
  Y = loadtxt('../data/rw-hist-N.txt', delimiter=',')

  width = X[1] - X[0]

  plt.bar(X[:-1] + width, Y, align = 'center', width = width)

  plt.title('Share value at exercise date')
  plt.xlabel(u'Share value - $aE$ / €')
  plt.ylabel('Random walk count data')

  plt.savefig('../tex/graphs/rw-hist.eps')
  plt.clf()


p_oP_plot()
p_profit_plot()
share_value_hist()
