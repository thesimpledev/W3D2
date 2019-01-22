require 'singleton'
require 'sqlite3'

class QuestionsDatabase < SQLite3::Database
    include Singleton

    def initialize
        super('questions.db')
        self.type_translation = true
        self.results_as_hash = true
    end
end

class User
    def self.find_by_id(id)
        data = QuestionsDatabase.instance.execute(<<-SQL, id)
            SELECT *
            FROM users
            WHERE id = ?
        SQL
        data.empty? ? nil : User.new(data.first)
    end

    def self.find_by_name(fname, lname)
        data = QuestionsDatabase.instance.execute(<<-SQL, fname, lname)
            SELECT *
            FROM users
            WHERE fname = ? AND lname = ?
        SQL
        data.empty? ? [] : data.map { |datum| User.new(datum) }
    end

    attr_accessor :id, :fname, :lname

    def initialize(options)
        @id = options['id']
        @fname = options['fname']
        @lname = options['lname']
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
end

class Question
    def self.find_by_id(id)
        data = QuestionsDatabase.instance.execute(<<-SQL, id)
            SELECT *
            FROM questions
            WHERE id = ?
        SQL
        data.empty? ? nil : Question.new(data.first)
    end

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

    attr_accessor :id, :title, :body, :author_id

    def initialize(options)
        @id = options['id']
        @title = options['title']
        @body = options['body']
        @author_id = options['author_id']
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
end

class Reply
    def self.find_by_id(id)
        data = QuestionsDatabase.instance.execute(<<-SQL, id)
            SELECT *
            FROM replies
            WHERE id = ?
        SQL
        data.empty? ? nil : Reply.new(data.first)
    end

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

    attr_accessor :id, :body, :reply_id, :question_id, :user_id

    def initialize(options)
        @id = options['id']
        @body = options['body']
        @reply_id = options['reply_id']
        @question_id = options['question_id']
        @user_id = options['user_id']
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
end