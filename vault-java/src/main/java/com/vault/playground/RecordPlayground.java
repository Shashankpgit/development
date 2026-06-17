package com.vault.playground;

public class RecordPlayground {

    // A DTO for creating a note — what the client sends
    record NoteRequest(String title, String content) {}

    // A DTO for returning a note — what the API sends back
    record NoteResponse(Long id, String title, String content) {}

    public static void main(String[] args) {

        // create a request
        NoteRequest request = new NoteRequest("My first note", "some content here");

        // access fields — notice: no "get" prefix
        System.out.println("Title   : " + request.title());
        System.out.println("Content : " + request.content());

        // toString is auto-generated
        System.out.println("Request : " + request);

        // create a response (what the service would return after saving to DB)
        NoteResponse response = new NoteResponse(1L, request.title(), request.content());
        System.out.println("Response: " + response);

        // equals works out of the box
        NoteRequest request2 = new NoteRequest("My first note", "some content here");
        System.out.println("Equal?  : " + request.equals(request2));  // true
    }
}
