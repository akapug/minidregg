// SPDX-License-Identifier: MIT
// Semantic read endpoint for the Mini integration build of YATA 0.1.2.
package main

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/gorilla/mux"
)

type apiTodo struct {
	ID          int64  `json:"id"`
	Done        bool   `json:"done"`
	Description string `json:"description"`
}

type apiPage struct {
	Entries []apiTodo `json:"entries"`
	Next    *int64    `json:"next"`
}

func registerTodoAPI(router *mux.Router, db *sql.DB) {
	router.Methods("GET").Path("/api/todos").HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		query := req.URL.Query()
		limit := 100
		var after int64
		var err error
		if value := query.Get("limit"); value != "" {
			limit, err = strconv.Atoi(value)
			if err != nil || limit < 1 || limit > 1000 {
				http.Error(w, "invalid limit", 400)
				return
			}
		}
		if value := query.Get("after"); value != "" {
			after, err = strconv.ParseInt(value, 10, 64)
			if err != nil || after < 0 {
				http.Error(w, "invalid after", 400)
				return
			}
		}
		done := -1
		switch query.Get("done") {
		case "", "all":
		case "true":
			done = 1
		case "false":
			done = 0
		default:
			http.Error(w, "invalid done filter", 400)
			return
		}
		rows, err := db.Query(`SELECT id, done, descr FROM todos WHERE id > ? AND (? < 0 OR done = ?) ORDER BY id LIMIT ?`, after, done, done, limit+1)
		if err != nil {
			http.Error(w, "task query failed", 500)
			return
		}
		defer rows.Close()
		page := apiPage{Entries: make([]apiTodo, 0, limit)}
		for rows.Next() {
			var entry apiTodo
			if err := rows.Scan(&entry.ID, &entry.Done, &entry.Description); err != nil {
				http.Error(w, "task decode failed", 500)
				return
			}
			if len(page.Entries) == limit {
				last := page.Entries[len(page.Entries)-1].ID
				page.Next = &last
				break
			}
			page.Entries = append(page.Entries, entry)
		}
		if err := rows.Err(); err != nil {
			http.Error(w, "task query failed", 500)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Cache-Control", "no-store")
		json.NewEncoder(w).Encode(page)
	})
}
