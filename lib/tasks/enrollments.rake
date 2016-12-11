
namespace :enrollments do
  desc "deactivate all enrollments"
  task :deactivate => :environment do
    Enrollment.active.update_all(status: 'CANCELLED')
  end
  
  
  desc "enrollments query"  
  task :query => :environment do

    class EncounterType < ActiveRecord::Base
      establish_connection Rails.configuration.database_configuration["openmrs"] 
      set_table_name :encounter_type
    end

    class Encounter < ActiveRecord::Base
      establish_connection Rails.configuration.database_configuration["openmrs"] 
      set_table_name :encounter
      def self.valid_by_type(type_name)
        where(:voided=>false, :encounter_type=>EncounterType.find_by_name(type_name).encounter_type_id)
      end
      def self.tips; valid_by_type("TIPS AND REMINDERS"); end
      def self.pg_status; valid_by_type("PREGNANCY STATUS"); end

      def obs_hash(allow_nil=false)
        Hash[*Observation.where(:encounter_id=>encounter_id).all.map(&:key_and_value).flatten]
      end

    end

    class Observation < ActiveRecord::Base
      establish_connection Rails.configuration.database_configuration["openmrs"] 
      set_table_name :obs
      def value
        #all relevant ones seem to be either text or coded
        value_text || value_decoded || value_datetime
      end
      def value_decoded 
        ConceptName.for_concept_id(value_coded).try(:name)
      end
      def label
        ConceptName.for_concept_id(concept_id).name
      end
<<<<<<< HEAD
=======
      def value_name
      end
      def value_decoded;
        cn = ConceptName.for_concept_id(value_coded)
        binding.pry if cn.nil?
        cn.name
      end
      def label; 
        cn = ConceptName.for_concept_id(concept_id)
        binding.pry if cn.nil?
        cn.name
      end      
>>>>>>> 0e77c95... value fix
      def key_and_value;  [label, value]; end
    end

    class ConceptName  < ActiveRecord::Base
      establish_connection Rails.configuration.database_configuration["openmrs"] 
      set_table_name :concept_name
      def self.for_concept_id(concept_id)
        #multiple names per concept
        where(:concept_id => concept_id).first
      end
    end

    class Patient < ActiveRecord::Base
      establish_connection Rails.configuration.database_configuration["openmrs"] 
      set_table_name :patient
    end

    national_id_type_id = Patient.find_by_sql("SELECT patient_identifier_type_id 
    FROM patient_identifier_type WHERE name='National id'").first.patient_identifier_type_id
    ivr_id_type_id = Patient.find_by_sql("SELECT patient_identifier_type_id 
    FROM patient_identifier_type WHERE name='IVR Access Code'").first.patient_identifier_type_id
    class Person < ActiveRecord::Base
      establish_connection Rails.configuration.database_configuration["openmrs"] 
      set_table_name :person
    end
    class PersonName < ActiveRecord::Base
      establish_connection Rails.configuration.database_configuration["openmrs"] 
      set_table_name :person_name
    end

    content_type_to_stream = {
      "Child" => "child",
      "CHILD" => "child",
      "Pregnancy" => "pregnancy",
      "PREGNANCY" => "pregnancy",
      "WCBA"      => "wcba",
    }

    lang_to_lang = {
      "Chichewa" => "Chichewa",
      "CHICHEWA" => "Chichewa",
      "Chiyao" => "Chiyao",
      "CHIYAO" => "Chiyao"
    } 
    message_type_to_delivery = {
      "SEND SMS" => "SMS",
      "SMS" => "SMS",
      "Voice" => "IVR",
      "VOICE" => "IVR"
    }

    enrollment_ids_to_cancel = Enrollment.active.map(&:id)
    debug_es = []
    #  desc "show verbose enrollment-related query results"
    #  task :show => :environment, :openmrs_models do
    all_tips_encounters=Encounter.tips.where("date_created > '2016-06-10'") #.order("patient_id ASC, date_created ASC")
    all_tips_encounters_by_patient= all_tips_encounters.group_by(&:patient_id)
<<<<<<< HEAD
    puts "#{all_tips_encounters_by_patient.size} patients"
=======
    warn "#{all_tips_encounters_by_patient.size} patients"
    #binding.pry
>>>>>>> 0e77c95... value fix
    all_tips_encounters_by_patient.each do |patient_id, encounters|
      patient_name = PersonName.find_by_person_id(patient_id)
      first_name = patient_name.given_name
      last_name = patient_name.family_name

      encounter_data = encounters.last.obs_hash
      
      national_id = Patient.find_by_sql("SELECT identifier FROM patient_identifier 
      WHERE patient_id = #{patient_id} AND identifier_type = #{national_id_type_id}").first.try(:identifier)

      ivr_id = Patient.find_by_sql("SELECT identifier FROM patient_identifier 
      WHERE patient_id = #{patient_id} AND identifier_type = #{ivr_id_type_id}").first.identifier
      ext_user_id = "#{ivr_id}/#{national_id}"

      phone = (encounter_data["Phone number"] || encounter_data["Telephone number"] || encounter_data["PHONE NUMBER"] || encounter_data["TELEPHONE NUMBER"]).to_s.gsub(" ","")
      phone.sub!(/^0/, '265')

      person_log_summary = "#{first_name} #{last_name} #{phone} #{ext_user_id} (#{patient_id})"

      puts "#{person_log_summary}"
      puts "     #{encounters.size} total, last #{encounters.last.date_created}  #{encounters.last.encounter_id}: #{encounter_data.inspect}"

      next if encounter_data["On tips and reminders program"] != "Yes" && encounter_data["ON TIPS AND REMINDERS PROGRAM"] != "YES"
      next if !phone.present? || phone =~ /^UNKNOWN$/i

      #all further 'next' skips are unexpected and should be logged as warnings
      #the intent is to catch holes in mnch-hotline's minimal enrollment validation logic. 
      skip_text = "Enrollment skipped for #{person_log_summary}:\n      "


      unless stream_name = content_type_to_stream[encounter_data["Type of message content"]] || content_type_to_stream[encounter_data["TYPE OF MESSAGE CONTENT"]]
        warn "Unsupported message type #{encounter_data["Type of message content"]||encounter_data["TYPE OF MESSAGE CONTENT"]} for #{person_log_summary}"
        next
      end

      stream = MessageStream.find_by_name(stream_name) 
      raise "stream not found for name #{stream_name}" if stream.nil?
      if stream_name=="child"
        stream_start = Person.find_by_person_id(patient_id).birthdate
      elsif stream_name=="pregnancy"
        pg_status_encounter = Encounter.pg_status.where(:patient_id=>patient_id).order("date_created DESC").first 
        if pg_status_encounter.nil?
          puts "#{skip_text} Pregnancy enrollment without pregnancy status encounter"
          next
        end
        if lmp = pg_status_encounter.obs_hash["Last menstrual period"]          
          stream_start = lmp
          due_date = lmp + 40.weeks
        elsif due_date = pg_status_encounter.obs_hash["Pregnancy due date"] 
          stream_start = due_date - 40.weeks
        else
          puts "#{skip_text} Pregnancy enrollment with pregnancy status encounter but without LMP or EDD 
          #{pg_status_encounter.encounter_id}, #{pg_status_encounter.obs_hash.inspect}"
          next
        end
        if due_date < Date.today
          puts "#{skip_text} Pregnancy enrollment with due date in the past
          #{pg_status_encounter.encounter_id}, #{pg_status_encounter.obs_hash.inspect}"
          next
        end
      elsif stream_name == "wcba"
        stream_start = encounters[0].encounter_datetime.to_date
        next if stream_start.nil?
      end

      #community phones disallowed from voice delivery
      if (encounter_data["Telephone number type"] == "Community phone" && encounter_data["message type"] == "Voice") || (encounter_data["TELEPHONE NUMBER TYPE "] == "COMMUNITY PHONE" && encounter_data["TYPE OF MESSAGE"] == "VOICE")
        puts "#{skip_text} Voice enrollment for community phone"
        next
      end

      raise "Unknown language #{encounter_data["Language preference"]}" unless language = lang_to_lang[encounter_data["Language preference"]] || lang_to_lang[encounter_data["LANGUAGE PREFERENCE"]]
      raise "Unknown delivery type #{encounter_data["message type"]}" unless delivery_method = message_type_to_delivery[encounter_data["message type"]]



      if enrollment = Enrollment.active.where(:ext_user_id=>ext_user_id,:message_stream_id=>stream.id).first
        enrollment_ids_to_cancel.delete(enrollment.id)
      else
        enrollment = Enrollment.new
      end

      attributes = {
        'first_name' => first_name,
        'last_name' => last_name,
        'phone_number' => phone,
        'message_stream_id' => stream.id,
        'language' => language,
        'delivery_method' => delivery_method,
        'stream_start' => stream_start,

        'ext_user_id' => ext_user_id,
        'status' => "ACTIVE"
      }
      enrollment.attributes = attributes

      if ENV['HMS_SAVE_ENROLLMENTS']
        enrollment.save!
      else
#        binding.pry unless ENV['STOPRY']
        puts ActiveSupport::OrderedHash[*attributes.sort.flatten].to_yaml
        debug_es << enrollment
      end

    end
    binding.pry
    if ENV['HMS_SAVE_ENROLLMENTS']
      Enrollment.find(enrollment_ids_to_cancel).each do |e|
        e.update_attributes(:status => Enrollment::CANCELLED)
      end
    end
    
  end

end

