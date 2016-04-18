"The module contains several _Junc_ examples:  
 * Echo service - [[package herd.junc.examples.echo]].  
 * Union data type usage with _Junc_ service and sockets - [[package herd.junc.examples.unionecho]].  
 * Multiservicing - [[package herd.junc.examples.multiservicing]].  
 "
native("jvm")
module herd.junc.examples "0.1.0" {
	import ceylon.collection "1.2.2";
	shared import herd.junc.api "0.1.0";
	shared import herd.junc.core "0.1.0";
}
