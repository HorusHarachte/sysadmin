#!/usr/bin/env python


plain = "HALLO DAS HIER IST EIN LANGER BEISPIELTEXT UM DAS VERFAHREN ZU ZEIGEN"
key_f = "NOTEBOOK"
key_s = "DECKEL"
#cipher = "NRSGSESAIEOZRABINADIILURTNDEHXUSRHEVIEEPAEHEEGTLZFTLIANMEL"


class DoppelWuerfel:

    def __init__(self):
        self.matrix = []
        self.trans = []


    @staticmethod
    def fill_in(text, key):
        j = 0       # Zaehler
        line = key  # Zeile
        a = []      # Matrix

        for i in text:
            if i != ' ':
                if j % len(key) == 0:       # Falls Zaehler gleich Schluessellaenge
                    j = 0
                    a.append(list(line))    # Zeile vollstaendig
                    line = ""

                line = line + i             # Zeile wird gefuellt
                j += 1

        while len(line) < len(key):     # Falls Schlusszeile kuerzer als Schuessellaenge
            line += " "                 # Auffuellen mit Leerzeichen
        a.append(list(line))

        return a


    def chiff(self, text, key):
        trans = []
        self.matrix = DoppelWuerfel.fill_in(text, key)    # Matrix wird gefuellt
        print self.matrix
        line = ""
        for x in range(len(self.matrix[0])):
            for y in range(len(self.matrix)):
                line = line + self.matrix[y][x]
            trans.append(list(line))
            line = ""
        print trans
        self.trans = sorted(trans, key=lambda trans_l: trans_l[0])
        
        for i in range(len(self.matrix[0])):
            for j in range(1, len(self.matrix)):
                line = line + self.trans[i][j]
    
        return line.replace(" ", "")
        # return line

    def dechiff(self, cipher_text, key):
        pass


if __name__ == "__main__":
    dw = DoppelWuerfel()
    cipher1 = dw.chiff(plain, key_f)
    cipher2 = dw.chiff(cipher1, key_s)
    print cipher2
