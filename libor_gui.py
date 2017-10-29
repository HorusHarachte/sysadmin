#!/usr/bin/env python

import tkMessageBox
import subprocess
import requests
from lxml import html
from Tkinter import Frame, Tk, Button, Label


class Libor:

    def __init__(self, url):
        self.page = requests.get(url)

    def get_libor(self):
        tree = html.fromstring(self.page.content)
        libor_val = \
            tree.xpath('//table[@class="table table-condensed instrument-detail-table"] \
                       /tbody/tr/td[@class="header_val nested"]/span/text()')
        libor_date = \
            tree.xpath('//table[@class="table table-condensed instrument-detail-table"] \
                       /tbody/tr/td[@class="header_val nested"]/div/span/text()')
        return [libor_date[0], libor_val[0]]

    @staticmethod
    def write_libor(value):
        with open('/lhome/horus/Documents/tinu/Hauskauf/libor.csv', 'a+') as f:
            first = f.readline()
            if first == '':
                f.write('date;value\n')
            f.seek(0)
            last = f.readlines()[-1]
            if last.split(';')[0] != value[0]:
                f.write(value[0] + ';' + value[1] + '\n')


class Application(Frame):

    def create_widgets(self):
    
        self.QUIT = Button(self)
        self.QUIT["text"] = "QUIT"
        self.QUIT["fg"] = "black"
        
        self.QUIT["command"] = self.quit
        self.QUIT.pack({"side": "bottom"})

        self.GetLibor = Label(self)
        self.GetLibor["text"] = self.value[0] + ': ' + self.value[1]
        self.GetLibor["fg"] = "blue"
        self.GetLibor["font"] = ("Arial", 48)

        self.GetLibor.pack({"side": "left"})

    def __init__(self, url, master=None):
        self.libor = Libor(url)
        self.value = self.libor.get_libor()
        Libor.write_libor(self.value)
        Frame.__init__(self, master)
        self.QUIT = Button(self)
        self.GetLibor = Label(self)
        self.pack()
        self.create_widgets()


root = Tk()
root.wm_title('Current Libor 3M')
site = 'https://www.cash.ch/devisen-zinsen/libor-3-months-chf-275669/ibal/chf'
app = Application(site, master=root)
app.mainloop()
root.destroy()
