###############################################################################
##
##  Copyright (C) 2014 Tavendo GmbH
##
##  Licensed under the Apache License, Version 2.0 (the "License");
##  you may not use this file except in compliance with the License.
##  You may obtain a copy of the License at
##
##      http://www.apache.org/licenses/LICENSE-2.0
##
##  Unless required by applicable law or agreed to in writing, software
##  distributed under the License is distributed on an "AS IS" BASIS,
##  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##  See the License for the specific language governing permissions and
##  limitations under the License.
##
###############################################################################

import sys

from twisted.python import log
from twisted.internet import reactor
from twisted.internet.defer import inlineCallbacks
from twisted.internet.endpoints import clientFromString

from autobahn.twisted import wamp, websocket
from autobahn.wamp import types
from autobahn.wamp import auth

PASSWORDS = {
  u'peter': u'secret1',
  u'joe': u'secret2'
}

USER = u'peter'
#USER = u'joe'


class MyFrontendComponent(wamp.ApplicationSession):
   """
   Application code goes here. This is an example component that calls
   a remote procedure on a WAMP peer, subscribes to a topic to receive
   events, and then stops the world after some events.
   """

   def onConnect(self):
      self.join(self.config.realm, [u"wampcra"], USER)

   def onChallenge(self, challenge):
      print challenge
      if challenge.method == u"wampcra":
         if u'salt' in challenge.extra:
            key = auth.derive_key(PASSWORDS[USER].encode('utf8'),
            challenge.extra['salt'].encode('utf8'),
            challenge.extra.get('iterations', None),
            challenge.extra.get('keylen', None))
         else:
            key = PASSWORDS[USER].encode('utf8')
         signature = auth.compute_wcs(key, challenge.extra['challenge'].encode('utf8'))
         return signature.decode('ascii')
      else:
         raise Exception("don't know how to compute challenge for authmethod {}".format(challenge.method))


   @inlineCallbacks
   def onJoin(self, details):

      ## call a remote procedure
      ##
      try:
         now = yield self.call(u'com.timeservice.now')
      except Exception as e:
         print("Error: {}".format(e))
      else:
         print("Current time from time service: {}".format(now))

      ## subscribe to a topic
      ##
      self.received = 0

      def on_event(i):
         print("Got event: {}".format(i))
         self.received += 1
         if self.received > 5:
            self.leave()

      sub = yield self.subscribe(on_event, u'com.myapp.topic1')
      print("Subscribed with subscription ID {}".format(sub.id))

      self.leave()


   def onLeave(self, details):
      print("onLeave: {}".format(details))
      self.disconnect()


   def onDisconnect(self):
      reactor.stop()



if __name__ == '__main__':

   ## 0) start logging to console
   log.startLogging(sys.stdout)

   ## 1) create a WAMP application session factory
   component_config = types.ComponentConfig(realm = "realm2")
   session_factory = wamp.ApplicationSessionFactory(config = component_config)
   session_factory.session = MyFrontendComponent

   ## optional: use specific set of serializers
   if False:
      serializers = None
   else:
      from autobahn.wamp.serializer import *
      serializers = []
      #serializers.append(JsonSerializer(batched=True))
      serializers.append(JsonSerializer(batched=False))

   ## 2) create a WAMP-over-WebSocket transport client factory
   transport_factory = websocket.WampWebSocketClientFactory(session_factory,
      url="ws://127.0.0.1:8080/wamp",
      serializers = serializers, debug = True, debug_wamp = True)

   ## 3) start the client from a Twisted endpoint
   client = clientFromString(reactor, "tcp:127.0.0.1:8080")
   client.connect(transport_factory)

   ## 4) now enter the Twisted reactor loop
   reactor.run()
