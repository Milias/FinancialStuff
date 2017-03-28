#!/bin/python
# -*- coding: utf-8 -*-
from numpy import *
import matplotlib.pyplot as plt

f_line = lambda x, a, b: a*(1-x)+b*x

def oP_X_plot(name, title, symbol):
  Xcall = loadtxt('../data/%s_%s_x.txt' % (name, 'call'), delimiter=',')
  Ycall = loadtxt('../data/%s_%s_mean.txt' % (name, 'call'), delimiter=',')
  stdcall = loadtxt('../data/%s_%s_std.txt' % (name, 'call'), delimiter=',')

  Xput = loadtxt('../data/%s_%s_x.txt' % (name, 'put'), delimiter=',')
  Yput = loadtxt('../data/%s_%s_mean.txt' % (name, 'put'), delimiter=',')
  stdput = loadtxt('../data/%s_%s_std.txt' % (name, 'put'), delimiter=',')

  plt.errorbar(Xcall, Ycall, yerr=stdcall, fmt='r.', label='Call')
  plt.errorbar(Xput, Yput, yerr=stdput, fmt='b.', label='Put')
  plt.axis([min(amin(Xcall), amin(Xput)), max(amax(Xcall), amax(Xput)), min(amin(Ycall), amin(Yput)), max(amax(Ycall), amax(Yput))])

  if name == 'stock':
    plt.plot([15, 15], [0, max(amax(Ycall), amax(Yput))], 'g--')

  plt.title('Option price v. %s' % title)
  plt.xlabel(r'$%s$ / %s' % (symbol, title))
  plt.ylabel(r'$\langle oP \rangle_{rf}$ / Option price')

  plt.legend(loc=0, numpoints=1)

  plt.savefig('../tex/graphs/oP_%s.eps' % name)
  plt.clf()

def long_call_option():
  oP = 5
  A = 10
  B = 20
  xmax = 30

  x = linspace(0, 1, 10)

  plt.plot(f_line(x, 0, A), f_line(x, -oP, -oP), 'r-', lw=3)
  plt.plot(f_line(x, A, A+oP), f_line(x, -oP, 0), 'g-', lw=3)
  plt.plot(f_line(x, A+oP, B), f_line(x, 0, B-A-oP), 'b-', lw=3)
  plt.plot(f_line(x, B, xmax), f_line(x, B-A-oP, B-A-oP), 'r-', lw=3)
  plt.plot(f_line(x, 0, xmax), f_line(x, 0, 0), 'k--', lw=3)

  plt.axis([0, xmax, -oP-2.5, B-A-oP+2.5])

  plt.title('10/20 long call spread with option price = %d' % oP)
  plt.xlabel('S / Share value')
  plt.ylabel('Profit')

  plt.savefig('../tex/graphs/long_call_option.eps')
  plt.clf()

def put_call_parity():
  oP = 5
  E = 15

  xmax = 2*E

  x = linspace(0, 1, 10)

  plt.plot(f_line(x, 0, xmax), f_line(x, 0, xmax), 'b-', lw=2, label='share value')

  plt.plot(f_line(x, 0, E), f_line(x, oP, oP), 'r-', lw=2, label='call (write)')
  plt.plot(f_line(x, E, xmax), f_line(x, oP, oP-xmax+E), 'r-', lw=2)

  plt.plot(f_line(x, 0, E), f_line(x, E-oP, -oP), 'g-', lw=2, label='put (buy)')
  plt.plot(f_line(x, E, xmax), f_line(x, -oP, -oP), 'g-', lw=2)

  plt.plot(f_line(x, 0, xmax), f_line(x, E, E), 'r--', lw=3, label='exercise price')
  plt.plot(f_line(x, 0, xmax), f_line(x, 0, 0), 'k-', lw=1)

  plt.plot([E, E], [-15, xmax], 'g--')

  plt.axis([0, xmax, -15, xmax])
  plt.legend(loc=0)

  plt.title('Put-call Parity with option price = %d and E = %d' % (oP, E))
  plt.xlabel('S / Share value')
  plt.ylabel('Profit')

  plt.savefig('../tex/graphs/put_call_parity.eps')
  plt.clf()

file_list = [
  ('stock', 'Stock price', 'aS'),
  ('vol', 'Volatility', r'\sigma'),
  ('dur', 'Duration (years)', 'aT'),
  ('drift', 'Drift', r'\mu')
]

for (name, title, symbol) in file_list: oP_X_plot(name, title, symbol)
long_call_option()
put_call_parity()
