CREATE TABLE gather_room (
  id SERIAL PRIMARY KEY,
  code VARCHAR(5) UNIQUE NOT NULL,
  title VARCHAR(255) NOT NULL,
  type VARCHAR(20) NOT NULL,
  owner_id VARCHAR(255) NOT NULL,
  status VARCHAR(10) NOT NULL DEFAULT 'open',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  expected_count INTEGER,
  voting_ends_at TIMESTAMP WITH TIME ZONE,
  winner_item_id INTEGER,
  was_tie BOOLEAN DEFAULT FALSE,
  current_step_id INTEGER
);

CREATE INDEX gather_room_owner_idx ON gather_room(owner_id);
CREATE INDEX gather_room_code_idx ON gather_room(code);

CREATE TABLE gather_member (
  id SERIAL PRIMARY KEY,
  room_id INTEGER NOT NULL REFERENCES gather_room(id) ON DELETE CASCADE,
  user_id VARCHAR(255) NOT NULL,
  display_name VARCHAR(255) NOT NULL,
  emoji VARCHAR(10) NOT NULL,
  role VARCHAR(10) NOT NULL DEFAULT 'guest',
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  checked_in_at TIMESTAMP WITH TIME ZONE,
  UNIQUE (user_id, room_id)
);

CREATE INDEX gather_member_room_idx ON gather_member(room_id);
CREATE INDEX gather_member_user_room_idx ON gather_member(user_id, room_id);

CREATE TABLE gather_item (
  id SERIAL PRIMARY KEY,
  room_id INTEGER NOT NULL REFERENCES gather_room(id) ON DELETE CASCADE,
  author_member_id INTEGER NOT NULL,
  kind VARCHAR(20) NOT NULL,
  text VARCHAR(280) NOT NULL,
  is_anonymous BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  vote_count INTEGER DEFAULT 0
);

CREATE INDEX gather_item_room_idx ON gather_item(room_id);

CREATE TABLE gather_vote (
  id SERIAL PRIMARY KEY,
  item_id INTEGER NOT NULL REFERENCES gather_item(id) ON DELETE CASCADE,
  member_id INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (item_id, member_id)
);

CREATE INDEX gather_vote_item_member_idx ON gather_vote(item_id, member_id);
CREATE INDEX gather_vote_item_idx ON gather_vote(item_id);

CREATE TABLE gather_agenda_step (
  id SERIAL PRIMARY KEY,
  room_id INTEGER NOT NULL REFERENCES gather_room(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  at TIMESTAMP WITH TIME ZONE,
  position INTEGER NOT NULL
);

CREATE INDEX gather_agenda_step_room_idx ON gather_agenda_step(room_id);
