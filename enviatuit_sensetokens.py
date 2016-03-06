# -*- coding: utf-8 -*-

#accedeix al timeline i printeja els 10 ultims twits

import tweepy
import time, sys


consumer_key = 'XXX'
consumer_secret = 'XXX'
access_token = 'XXX'
access_secret = 'XXX'

auth = tweepy.OAuthHandler(consumer_key, consumer_secret)
auth.set_access_token(access_token, access_secret)

nomwifi= str(sys.argv[1])
contrassenya= str(sys.argv[2])

#print ("Nom wlan: %s" % nomwlan)
#print ("Contrassenya: %s" % contrassenya)

missatge= "#tweetdesdecodi #wifiautomatic Nom wifi: " + nomwifi + ", contrassenya: " + contrassenya

print (missatge)

api = tweepy.API(auth)
api.update_status(status=missatge)
