import herd.junc.api {
	
	Station,
	ServiceAddress,
	JuncSocket,
	ServiceAddedEvent,
	JuncTrack,
	Junc,
	JuncService,
	Promise
}
import herd.junc.core {
	
	startJuncCore,
	Railway
}


shared void runUnionEchoService() {
	// starting Junc
	startJuncCore().onComplete (
		// listen the Junc is started
		(Railway railway) {
			// deploying echo station
			railway.deployStation(EchoUnionStation(railway)).onComplete (
				(Object obj)
						=> print("echo union station is successfully deployed"),
				(Throwable reason)
						=> print("error while deploying echo union station ``reason``")
			);
		}
	);
}


class EchoUnionStation(Railway railway) satisfies Station {
	
	// address implementing echo service has to listen to
	ServiceAddress echoAddress = ServiceAddress("echo union service");

	// number of the receeived messages by the client - used to stop the Junc 
	variable Integer numberOfReplies = 0;
	
	// handler - echo service connected
	void onUnionEchoService(JuncSocket<String|Integer, String|Integer> socket) {
		// listen data emission and resend it back
		socket.onData (
			(String|Integer data) {
				//socket.publish(data);
				switch (data)
				case (is String) {socket.publish(data);}
				case (is Integer) {socket.publish(data);}
			}
		);
	}
	
	// handler - echo client connection established
	void onStringEchoClient(JuncSocket<String, String> socket) {
		String hello = "Hello!";
		// listen data emission - it must be the same as sent 'hello'
		socket.onData (
			(String data) => print("string client sent '``hello``' and received '``data``'")
		);
		// send data to service
		socket.publish(hello);
	}
	
	// handler - echo client connection established
	void onIntegerEchoClient(JuncSocket<Integer, Integer> socket) {
		Integer hello = 1;
		// listen data emission - it must be the same as sent 'hello'
		socket.onData (
			(Integer data) => print("integer client sent '``hello``' and received '``data``'")
		);
		// send data to service
		socket.publish(hello);
	}
	
	// handler - echo client connection established
	void onUnionEchoClient(JuncSocket<String|Integer, String|Integer> socket) {
		String hello = "Hello from union!";
		Integer intHello = 10;
		// listen data emission - it must be the same as sent 'hello'
		socket.onData (
			(String|Integer data) {
				switch (data)
				case (is String) {print("union client sent '``hello``' and received '``data``'");}
				case (is Integer) {print("union client sent '``intHello``' and received '``data``'");}
				if ( ++ numberOfReplies > 1 ) {
					// stop the Junc if all messages have been received
					railway.stop();
				}
			}
		);
		// send data to service
		socket.publish(hello);
		socket.publish(intHello);
	}
	
	// listener of service added event
	void onEchoServiceRegistered(JuncTrack track)(ServiceAddedEvent<String, String> event) {
		if (is ServiceAddress address = event.service.address) {
			track.connect<String, String, ServiceAddress>(address)
					.onComplete(onStringEchoClient);            
			track.connect<Integer, Integer, ServiceAddress>(address)
					.onComplete(onIntegerEchoClient);            
			track.connect<String|Integer, String|Integer, ServiceAddress>(address)
					.onComplete(onUnionEchoClient);            
		}
	}
	
	// station start method
	shared actual Promise<Object> start(JuncTrack track, Junc junc) {
		// register echo service
		track.juncEvents.onData(onEchoServiceRegistered(track));
		return track.registerService<String|Integer, String|Integer, ServiceAddress>(echoAddress)
				.onComplete (
			// service registration handler
			(JuncService<String|Integer, String|Integer> service) {
				// service has been registered - listen connection
				service.onConnected(onUnionEchoService);
			}
		);
	}
}
