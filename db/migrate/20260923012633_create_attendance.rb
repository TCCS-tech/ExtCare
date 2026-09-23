class CreateAttendance < ActiveRecord::Migration[8.1]
  def up
    create_table :attendance do |t|
      t.references :student, null: false, foreign_key: { on_delete: :restrict }
      t.date :day, null: false
      t.timestamptz :checkin, null: false
      t.timestamptz :checkout
      t.bigint :checkin_by, null: false
      t.text :pickup_notes
      t.timestamps
    end

    add_foreign_key :attendance, :users, column: :checkin_by, on_delete: :restrict
    add_index :attendance, :checkin_by
    add_index :attendance, [ :student_id, :day ]
    add_index :attendance, :student_id,
      unique: true,
      where: "checkout IS NULL",
      name: "attendance_one_open_per_student"

    add_check_constraint :attendance,
      "checkout IS NULL OR checkout > checkin",
      name: "attendance_checkout_after_checkin"

    execute <<~SQL
      CREATE OR REPLACE FUNCTION attendance_enforce_visit_rules()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        IF NEW.checkout IS NOT NULL AND NEW.checkout <= NEW.checkin THEN
          RAISE EXCEPTION
            'checkout (%) must be after checkin (%)',
            NEW.checkout, NEW.checkin
            USING ERRCODE = 'check_violation';
        END IF;

        IF EXISTS (
          SELECT 1
          FROM attendance a
          WHERE a.student_id = NEW.student_id
            AND a.checkout   IS NULL
            AND a.id         IS DISTINCT FROM NEW.id
        ) THEN
          RAISE EXCEPTION
            'student % already has an open checkin; checkout first',
            NEW.student_id
            USING ERRCODE = 'exclusion_violation';
        END IF;

        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER attendance_enforce_visit_rules
        BEFORE INSERT OR UPDATE OF student_id, day, checkin, checkout
        ON attendance
        FOR EACH ROW
        EXECUTE FUNCTION attendance_enforce_visit_rules();
    SQL
  end

  def down
    execute "DROP TRIGGER IF EXISTS attendance_enforce_visit_rules ON attendance"
    execute "DROP FUNCTION IF EXISTS attendance_enforce_visit_rules()"
    drop_table :attendance
  end
end
