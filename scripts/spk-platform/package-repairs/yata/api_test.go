package main

import (
	"database/sql"
	"encoding/json"
	"github.com/gorilla/mux"
	"net/http/httptest"
	"testing"
)

func TestTodoAPIPageFilterAndBounds(t *testing.T) {
	db, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	if _, err := db.Exec(`CREATE TABLE todos (id INTEGER PRIMARY KEY, done BOOL NOT NULL, descr TEXT NOT NULL); INSERT INTO todos VALUES (1,0,'one'),(2,1,'two'),(3,0,'three')`); err != nil {
		t.Fatal(err)
	}
	router := mux.NewRouter()
	registerTodoAPI(router, db)
	get := func(path string) *httptest.ResponseRecorder {
		response := httptest.NewRecorder()
		router.ServeHTTP(response, httptest.NewRequest("GET", path, nil))
		return response
	}
	decode := func(path string) apiPage {
		response := get(path)
		if response.Code != 200 {
			t.Fatalf("%s: status %d", path, response.Code)
		}
		var page apiPage
		if err := json.Unmarshal(response.Body.Bytes(), &page); err != nil {
			t.Fatal(err)
		}
		return page
	}
	first := decode("/api/todos?limit=1&done=false")
	if len(first.Entries) != 1 || first.Entries[0].ID != 1 || first.Next == nil || *first.Next != 1 {
		t.Fatalf("bad first page: %#v", first)
	}
	last := decode("/api/todos?limit=1&done=false&after=1")
	if len(last.Entries) != 1 || last.Entries[0].ID != 3 || last.Next != nil {
		t.Fatalf("bad final page: %#v", last)
	}
	empty := decode("/api/todos?after=3")
	if empty.Entries == nil || len(empty.Entries) != 0 || empty.Next != nil {
		t.Fatalf("bad empty page: %#v", empty)
	}
	done := decode("/api/todos?done=true")
	if len(done.Entries) != 1 || done.Entries[0].Description != "two" || !done.Entries[0].Done {
		t.Fatalf("bad done filter: %#v", done)
	}
	for _, query := range []string{"limit=0", "limit=1001", "limit=x", "after=-1", "after=overflow", "done=yes"} {
		if response := get("/api/todos?" + query); response.Code != 400 {
			t.Fatalf("accepted invalid %s", query)
		}
	}
}
