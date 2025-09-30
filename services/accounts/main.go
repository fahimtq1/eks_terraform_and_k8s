package main

import (
	"fmt"
	"log"
	"net/http"
)

// handler is a function that will handle incoming HTTP requests.
func handler(w http.ResponseWriter, r *http.Request) {
	log.Printf("Received request from %s for %s", r.RemoteAddr, r.URL.Path)
	// Write a simple response to the client.
	fmt.Fprintf(w, "Hello from the Accounts Service!")
}

func main() {
	// Register the handler function for the root URL path "/".
	http.HandleFunc("/", handler)

	// Define the port the server will listen on.
	port := "8080"
	log.Printf("Starting accounts service on port %s...", port)

	// Start the HTTP server. If it fails, log the error and exit.
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Could not start server: %s\n", err)
	}
}
