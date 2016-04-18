import herd.junc.api {

	Station,
	ServiceAddress,
	JuncSocket,
	ServiceAddedEvent,
	JuncTrack,
	Junc,
	JuncService,
	Promise,
	Message
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
            railway.deployStation(EchoMessageStation(railway)).onComplete (
                (Object obj)
                    => print("echo station is successfully deployed"),
                (Throwable reason)
                    => print("error while deploying echo station ``reason``")
            );
        }
    );
}

// Message which contains String body and can be replied with String
alias StringMessage => Message<String, String>;

class EchoMessageStation(Railway railway) satisfies Station {
	
	// address implementing echo service has to listen to
	ServiceAddress echoAddress = ServiceAddress("echo service");
	
	// echo service connected handler
	void onEchoService(JuncTrack track)(JuncSocket<StringMessage, Nothing> socket) {
		// listen income messages and reply on with received data
		socket.onData((StringMessage data)
			=> data.reply(track.createMessage<String, String>(data.body)));
	}
	
	// echo client handler
	void onEchoClient(JuncTrack track)(JuncSocket<Nothing, StringMessage> socket) {
		String hello = "Hello!";
		// send data to service
		socket.publish (
			// sent data is Message!
			track.createMessage (
				hello, // message body or data
				// message reply handler - reseived message has to be equal to sent one
				(StringMessage data) {
					print("'``hello``' message is replied with '``data.body``'");
					railway.stop();
				},
				// message rejection handler
				(Throwable reason) {
					print("message is rejected with reason ``reason``");
					railway.stop();
				}
			)
		);
	}
		
	// listenes service added event and establish connection to
	void onEchoServiceRegistered(JuncTrack track)(ServiceAddedEvent<Nothing, StringMessage> event) {
		if (is ServiceAddress address = event.service.address) {
			track.connect<Nothing, StringMessage, ServiceAddress>(address)
					.onComplete(onEchoClient(track));            
		}
	}
	
	// station start method
	shared actual Promise<Object> start(JuncTrack track, Junc junc) {
		// register echo service
		track.juncEvents.onData(onEchoServiceRegistered(track));
		return track.registerService<Nothing, StringMessage, ServiceAddress>(echoAddress)
				.onComplete (
			// service registration handler
			(JuncService<Nothing, StringMessage> service) {
				// service has been registered - listen connection
				service.onConnected(onEchoService(track));
			}
		);
	}
}
