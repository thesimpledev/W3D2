require 'singleton'
require 'sqlite3'
require 'active_support/inflector'

class QuestionsDatabase < SQLite3::Database
    include Singleton

    def initialize
        super('questions.db')
        self.type_translation = true
        self.results_as_hash = true
    end
end

class ModelBase
    def self.find_by_id(id)        
        data = QuestionsDatabase.instance.execute(<<-SQL, id)
            SELECT *
            FROM #{to_s.tableize}
            WHERE id = ?
        SQL
        data.empty? ? nil : new(data.first)
    end

    def self.all
        data = QuestionsDatabase.instance.execute(<<-SQL)
            SELECT *
            FROM #{to_s.tableize}
        SQL
        data.empty? ? [] : data.map { |datum| new(datum) }       
    end

    def self.where(options)
        options = (options.is_a?(String) ? options : parse_options(options))
        data = QuestionsDatabase.instance.execute(<<-SQL)
            SELECT *
            FROM #{to_s.tableize}
            WHERE #{options}
        SQL
        data.empty? ? [] : data.map { |datum| new(datum) }    
    end

    def self.find_by(options)
        where(options).first
    end

    private

    def self.parse_options(options)
        output = []

        options.each do |key, val|
            output << "#{key} = '#{val}'"
        end
        
        output.join(" AND ")
    end
end

class User < ModelBase
    def self.find_by_name(fname, lname)
        data = QuestionsDatabase.instance.execute(<<-SQL, fname, lname)
            SELECT *
            FROM users
            WHERE fname = ? AND lname = ?
        SQL
        data.empty? ? [] : data.map { |datum| User.new(datum) }
    end

    attr_accessor :fname, :lname
    attr_reader :id

    def initialize(options)
        @id = options['id']
        @fname = options['fname']
        @lname = options['lname']
    end

    def save
        id ? update : insert
    end

    def authored_questions
        Question.find_by_author_id(id)
    end

    def authored_replies
        Reply.find_by_user_id(id)
    end

    def followed_questions
        QuestionFollow.followed_questions_for_user_id(id)
    end

    def liked_questions
        QuestionLike.liked_questions_for_user_id(id)
    end

    def average_karma
        data = QuestionsDatabase.instance.execute(<<-SQL, id)
            SELECT COUNT(DISTINCT questions.id) / CAST(COUNT(COALESCE(user_id, 0)) AS FLOAT) AS karma
            FROM questions
            LEFT JOIN question_likes
                ON questions.id = question_id
            WHERE
                user_id = ?
        SQL
        data.first['karma']
    end

    private

    def update
        QuestionsDatabase.instance.execute(<<-SQL, fname, lname, id)
            UPDATE users
            SET fname = ?, lname = ?
            WHERE id = ?
        SQL
    end

    def insert
        QuestionsDatabase.instance.execute(<<-SQL, fname, lname)
            INSERT INTO users ('fname', 'lname')
            VALUES (?, ?)
        SQL
        @id = QuestionsDatabase.instance.last_insert_row_id
    end
end

class Question < ModelBase
    def self.find_by_author_id(author_id)
        data = QuestionsDatabase.instance.execute(<<-SQL, author_id)
            SELECT *
            FROM questions
            WHERE author_id = ?
        SQL
        data.empty? ? [] : data.map { |datum| Question.new(datum) }
    end

    def self.most_followed(n)
        QuestionFollow.most_followed_questions(n)
    end

    def self.most_liked(n)
        QuestionLike.most_liked_questions(n)
    end

    attr_accessor :title, :body, :author_id
    attr_reader :id

    def initialize(options)
        @id = options['id']
        @title = options['title']
        @body = options['body']
        @author_id = options['author_id']
    end

    def save
        id ? update : insert
    end

    def author
        User.find_by_id(author_id)
    end

    def replies
        Reply.find_by_question_id(id)
    end

    def followers
        QuestionsFollow.followers_for_question_id(id)
    end

    def likers
        QuestionLike.likers_for_question_id(id)
    end

    def num_likes
        QuestionLike.num_likes_for_question_id(id)
    end

    private

    def update
        QuestionsDatabase.instance.execute(<<-SQL, title, body, author_id, id)
            UPDATE questions
            SET title = ?, body = ?, author_id = ?
            WHERE id = ?
        SQL
    end

    def insert
        QuestionsDatabase.instance.execute(<<-SQL, title, body, author_id)
            INSERT INTO questions ('title', 'body', 'author_id')
            VALUES (?, ?, ?)
        SQL
        @id = QuestionsDatabase.instance.last_insert_row_id
    end
end

class Reply < ModelBase
    def self.find_by_user_id(user_id)
        data = QuestionsDatabase.instance.execute(<<-SQL, user_id)
            SELECT *
            FROM replies
            WHERE user_id = ?
        SQL
        data.empty? ? [] : data.map { |datum| Reply.new(datum) }
    end

    def self.find_by_question_id(question_id)
        data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
            SELECT *
            FROM replies
            WHERE question_id = ?
        SQL
        data.empty? ? [] : data.map { |datum| Reply.new(datum) }
    end

    def self.find_by_reply_id(id)
        data = QuestionsDatabase.instance.execute(<<-SQL, id)
            SELECT *
            FROM replies
            WHERE reply_id = ?
        SQL
        data.empty? ? [] : data.map { |datum| Reply.new(datum) }
    end

    attr_accessor :body, :reply_id, :question_id, :user_id
    attr_reader :id

    def initialize(options)
        @id = options['id']
        @body = options['body']
        @reply_id = options['reply_id']
        @question_id = options['question_id']
        @user_id = options['user_id']
    end

    def save
        id ? update : insert
    end

    def author
        User.find_by_id(user_id)
    end

    def question
        Question.find_by_id(question_id)
    end

    def parent_reply
        Reply.find_by_id(reply_id)
    end

    def child_replies
        Reply.find_by_reply_id(id)
    end

    private

    def update
        QuestionsDatabase.instance.execute(<<-SQL, body, reply_id, question_id, user_id, id)
            UPDATE replies
            SET body = ?, reply_id = ?, question_id = ?, user_id = ?
            WHERE id = ?
        SQL
    end

    def insert
        QuestionsDatabase.instance.execute(<<-SQL, body, reply_id, question_id, user_id)
            INSERT INTO replies ('body', 'reply_id', 'question_id', 'user_id')
            VALUES (?, ?, ?, ?)
        SQL
        @id = QuestionsDatabase.instance.last_insert_row_id
    end
end

class QuestionFollow
    def self.followers_for_question_id(question_id)
        data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
            SELECT *
            FROM users
            JOIN question_follows
                ON user_id = users.id
            WHERE question_id = ?
        SQL
        data.empty? ? [] : data.map { |datum| User.new(datum) }
    end

    def self.followed_questions_for_user_id(user_id)
        data = QuestionsDatabase.instance.execute(<<-SQL, user_id)
            SELECT *
            FROM questions
            JOIN question_follows
                ON question_id = questions.id
            WHERE question_follows.user_id = ?
        SQL
        data.empty? ? [] : data.map { |datum| Question.new(datum) }
    end

    def self.most_followed_questions(n)
        data = QuestionsDatabase.instance.execute(<<-SQL, n)
            SELECT *
            FROM questions
            JOIN question_follows
                ON question_id = questions.id
            GROUP BY question_id
            ORDER BY COUNT(*) DESC
            LIMIT ?
        SQL
        data.empty? ? [] : data.map { |datum| Question.new(datum) }
    end
end

class QuestionLike
    def self.likers_for_question_id(question_id)
        data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
            SELECT *
            FROM questions
            JOIN question_likes
                ON user_id = questions.author_id
            JOIN users
                ON user_id = users.id
            WHERE
                questions.id = ?
        SQL
        data.empty? ? [] : data.map { |datum| User.new(datum) }        
    end

    def self.num_likes_for_question_id(question_id)
        data = QuestionsDatabase.instance.execute(<<-SQL, question_id)
            SELECT COUNT(*)
            FROM questions
            JOIN question_likes
                ON user_id = questions.author_id
            JOIN users
                ON user_id = users.id
            WHERE
                questions.id = ?
        SQL
        data.first.values.first
    end

    def self.liked_questions_for_user_id(user_id)
        data = QuestionsDatabase.instance.execute(<<-SQL, user_id)
            SELECT *
            FROM questions
            JOIN question_likes
                ON user_id = questions.author_id
            JOIN users
                ON user_id = users.id
            WHERE
                user_id = ?
        SQL
        data.empty? ? [] : data.map { |datum| Question.new(datum) }        
    end

    def self.most_liked_questions(n)
        data = QuestionsDatabase.instance.execute(<<-SQL, n)
            SELECT *
            FROM questions
            JOIN question_likes
                ON question_id = questions.id
            GROUP BY question_id
            ORDER BY COUNT(*) DESC
            LIMIT ?
        SQL
        data.empty? ? [] : data.map { |datum| Question.new(datum) }
    end
end