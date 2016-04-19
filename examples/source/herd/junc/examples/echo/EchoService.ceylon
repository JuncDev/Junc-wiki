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


shared void runEchoService() {
    // starting Junc
    startJuncCore().onComplete (
        // listen the Junc is started
        (Railway railway) {
            // deploying echo station
            railway.deployStation(EchoStation(railway)).onComplete (
                (Object obj)
                    => print("echo station is successfully deployed"),
                (Throwable reason)
                    => print("error while deploying echo station ``reason``")
            );
        }
    );
}


class EchoStation(Railway railway) satisfies Station {
	
	// address implementing echo service has to listen to
	ServiceAddress echoAddress = ServiceAddress("echo service");
	
	// handler - echo service connected
	void onEchoService(JuncSocket<String, String> socket) {
		// listen data emission and resend it back
		socket.onData((String data) => socket.publish(data));
	}
	
	// handler - echo client connection established
	void onEchoClient(JuncSocket<String, String> socket) {
		String hello = "Hello!";
		// listen data emission - it must be the same as sent 'hello'
		socket.onData (
			(String data) {
				// client receives echo
				print("sent '``hello``' and received '``data``'");
				// stop the Junc
				railway.stop();
			}
		);
		// send data to service
		socket.publish(hello);
	}
	
	// listener of service added event
	void onEchoServiceRegistered(JuncTrack track)(ServiceAddedEvent<String, String, ServiceAddress> event) {
		track.connect<String, String, ServiceAddress>(event.service.address)
				.onComplete(onEchoClient);            
	}
	
	// station start method
	shared actual Promise<Object> start(JuncTrack track, Junc junc) {
		// register echo service
		track.juncEvents.onData(onEchoServiceRegistered(track));
		return track.registerService<String, String, ServiceAddress>(echoAddress)
				.onComplete (
			// service registration handler
			(JuncService<String, String> service) {
				// service has been registered - listen connection
				service.onConnected(onEchoService);
			}
		);
	}
}
