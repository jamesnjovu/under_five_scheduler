# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     App.Repo.insert!(%App.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias App.Accounts
alias App.Scheduling
alias App.Repo
alias App.Config.Specializations
import Ecto.Query

# Helper function to get or create user
get_or_create_user = fn attrs ->
  case Accounts.get_user_by_email(attrs["email"]) do
    nil ->
      Accounts.register_user(attrs)
    user ->
      {:ok, user}
  end
end

# Helper function to get specialization_id by code
get_specialization_id = fn code ->
  from(s in App.Config.Specialization, where: s.code == ^code, select: s.id)
  |> Repo.one()
end

IO.puts("🌱 Starting database seeding...")

# Create admin user
IO.puts("Creating admin user...")
case get_or_create_user.(%{
  "name" => "Admin User",
  "email" => "admin@example.com",
  "phone" => "+1234567890",
  "password" => "adminpassword123",
  "password_confirmation" => "adminpassword123",
  "role" => "admin"
}) do
  {:ok, admin} ->
    IO.puts("✅ Admin user created: #{admin.email}")
  {:error, changeset} ->
    IO.puts("⚠️  Admin user creation failed: #{inspect(changeset.errors)}")
end

# Create provider users and their provider profiles
IO.puts("Creating provider users...")

providers_data = [
  %{
    user: %{
      "name" => "Dr. Sarah Johnson",
      "email" => "sarah.johnson@example.com",
      "phone" => "+260978921730",
      "password" => "providerpass123",
      "password_confirmation" => "providerpass123",
      "role" => "provider"
    },
    provider: %{
      "name" => "Dr. Sarah Johnson",
      "specialization_code" => "pediatrician",
      "license_number" => "MD-ZM-001234"
    }
  },
  %{
    user: %{
      "name" => "Dr. Michael Chen",
      "email" => "michael.chen@example.com",
      "phone" => "+260978921731",
      "password" => "providerpass123",
      "password_confirmation" => "providerpass123",
      "role" => "provider"
    },
    provider: %{
      "name" => "Dr. Michael Chen",
      "specialization_code" => "general_practitioner",
      "license_number" => "MD-ZM-001235"
    }
  },
  %{
    user: %{
      "name" => "Nurse Jane Smith",
      "email" => "jane.smith@example.com",
      "phone" => "+260978921732",
      "password" => "providerpass123",
      "password_confirmation" => "providerpass123",
      "role" => "provider"
    },
    provider: %{
      "name" => "Nurse Jane Smith",
      "specialization_code" => "nurse",
      "license_number" => "RN-ZM-005678"
    }
  },
  %{
    user: %{
      "name" => "Clinical Officer Mary Banda",
      "email" => "mary.banda@example.com",
      "phone" => "+260978921733",
      "password" => "providerpass123",
      "password_confirmation" => "providerpass123",
      "role" => "provider"
    },
    provider: %{
      "name" => "Clinical Officer Mary Banda",
      "specialization_code" => "clinical_officer",
      "license_number" => "CO-ZM-002345"
    }
  },
  %{
    user: %{
      "name" => "CHW Grace Mwanza",
      "email" => "grace.mwanza@example.com",
      "phone" => "+260978921734",
      "password" => "providerpass123",
      "password_confirmation" => "providerpass123",
      "role" => "provider"
    },
    provider: %{
      "name" => "CHW Grace Mwanza",
      "specialization_code" => "community_health_worker",
      "license_number" => nil  # CHWs don't require license
    }
  }
]

providers =
  Enum.map(providers_data, fn data ->
    case get_or_create_user.(data.user) do
      {:ok, user} ->
        # Get specialization_id from the new table
        specialization_id = get_specialization_id.(data.provider["specialization_code"])

        if specialization_id do
          provider_attrs = data.provider
                           |> Map.put("user_id", user.id)
                           |> Map.put("specialization_id", specialization_id)
                           |> Map.put("specialization", data.provider["specialization_code"])  # Keep for backward compatibility
                           |> Map.delete("specialization_code")

          case Scheduling.get_provider_by_user_id(user.id) do
            nil ->
              case Scheduling.create_provider(provider_attrs) do
                {:ok, provider} ->
                  IO.puts("✅ Provider created: #{provider.name}")
                  provider
                {:error, changeset} ->
                  IO.puts("⚠️  Provider creation failed for #{data.user["name"]}: #{inspect(changeset.errors)}")
                  nil
              end
            existing_provider ->
              IO.puts("ℹ️  Provider already exists: #{existing_provider.name}")
              existing_provider
          end
        else
          IO.puts("❌ Specialization '#{data.provider["specialization_code"]}' not found for #{data.user["name"]}")
          nil
        end
      {:error, changeset} ->
        IO.puts("⚠️  User creation failed for #{data.user["name"]}: #{inspect(changeset.errors)}")
        nil
    end
  end)
  |> Enum.filter(&(&1 != nil))

IO.puts("Created #{length(providers)} providers")

# Create schedules for providers
IO.puts("Creating provider schedules...")
Enum.each(providers, fn provider ->
  # Check if schedules already exist
  existing_schedules = from(s in App.Scheduling.Schedule, where: s.provider_id == ^provider.id, select: s.id) |> Repo.all()

  if length(existing_schedules) == 0 do
    # Monday through Friday, 8 AM to 5 PM
    Enum.each(1..5, fn day ->
      case Scheduling.create_schedule(provider, %{
        "day_of_week" => day,
        "start_time" => ~T[08:00:00],
        "end_time" => ~T[17:00:00]
      }) do
        {:ok, _schedule} ->
          :ok
        {:error, changeset} ->
          IO.puts("⚠️  Schedule creation failed for provider #{provider.name}, day #{day}: #{inspect(changeset.errors)}")
      end
    end)
    IO.puts("✅ Schedules created for #{provider.name}")
  else
    IO.puts("ℹ️  Schedules already exist for #{provider.name}")
  end
end)

# Create sample parent users
IO.puts("Creating parent users...")

parents_data = [
  %{
    "name" => "John Doe",
    "email" => "john.doe@example.com",
    "phone" => "+260978921800",
    "password" => "parentpass123",
    "password_confirmation" => "parentpass123",
    "role" => "parent"
  },
  %{
    "name" => "Mary Tembo",
    "email" => "mary.tembo@example.com",
    "phone" => "+260978921801",
    "password" => "parentpass123",
    "password_confirmation" => "parentpass123",
    "role" => "parent"
  },
  %{
    "name" => "Peter Mwila",
    "email" => "peter.mwila@example.com",
    "phone" => "+260978921802",
    "password" => "parentpass123",
    "password_confirmation" => "parentpass123",
    "role" => "parent"
  }
]

parents =
  Enum.map(parents_data, fn parent_data ->
    case get_or_create_user.(parent_data) do
      {:ok, parent} ->
        IO.puts("✅ Parent created: #{parent.name}")
        parent
      {:error, changeset} ->
        IO.puts("⚠️  Parent creation failed for #{parent_data["name"]}: #{inspect(changeset.errors)}")
        nil
    end
  end)
  |> Enum.filter(&(&1 != nil))

# Create children for parents
IO.puts("Creating children...")

children_data = [
  # John Doe's children
  {0, [
    %{
      "name" => "Emma Doe",
      "date_of_birth" => ~D[2021-06-15]
    },
    %{
      "name" => "Oliver Doe",
      "date_of_birth" => ~D[2023-02-10]
    }
  ]},
  # Mary Tembo's children
  {1, [
    %{
      "name" => "Grace Tembo",
      "date_of_birth" => ~D[2020-11-20]
    },
    %{
      "name" => "Joseph Tembo",
      "date_of_birth" => ~D[2022-08-05]
    }
  ]},
  # Peter Mwila's children
  {2, [
    %{
      "name" => "Ruth Mwila",
      "date_of_birth" => ~D[2021-03-12]
    }
  ]}
]

all_children =
  Enum.flat_map(children_data, fn {parent_index, children_list} ->
    if parent_index < length(parents) do
      parent = Enum.at(parents, parent_index)

      Enum.map(children_list, fn child_data ->
        # Check if child already exists
        existing_children = Accounts.list_children(parent.id)
        existing_child = Enum.find(existing_children, &(&1.name == child_data["name"]))

        if existing_child do
          IO.puts("ℹ️  Child already exists: #{existing_child.name}")
          existing_child
        else
          case Accounts.create_child(parent, child_data) do
            {:ok, child} ->
              IO.puts("✅ Child created: #{child.name} (parent: #{parent.name})")
              child
            {:error, changeset} ->
              IO.puts("⚠️  Child creation failed for #{child_data["name"]}: #{inspect(changeset.errors)}")
              nil
          end
        end
      end)
      |> Enum.filter(&(&1 != nil))
    else
      []
    end
  end)

IO.puts("Created #{length(all_children)} children")

# Create sample appointments
IO.puts("Creating sample appointments...")

if length(providers) > 0 and length(all_children) > 0 do
  today = Date.utc_today()

  # Create appointments for next 2 weeks
  appointment_dates = [
    Date.add(today, 1),
    Date.add(today, 3),
    Date.add(today, 7),
    Date.add(today, 10),
    Date.add(today, 14)
  ]

  appointment_times = [
    ~T[09:00:00],
    ~T[10:30:00],
    ~T[14:00:00],
    ~T[15:30:00]
  ]

  Enum.with_index(all_children)
  |> Enum.take(5)  # Create max 5 appointments
  |> Enum.each(fn {child, index} ->
    provider = Enum.at(providers, rem(index, length(providers)))
    date = Enum.at(appointment_dates, rem(index, length(appointment_dates)))
    time = Enum.at(appointment_times, rem(index, length(appointment_times)))

    # Check if appointment already exists
    existing_appointments = Scheduling.list_appointments(
      child_id: child.id,
      provider_id: provider.id,
      date: date
    )

    if length(existing_appointments) == 0 do
      case Scheduling.create_appointment(%{
        child_id: child.id,
        provider_id: provider.id,
        scheduled_date: date,
        scheduled_time: time,
        status: "scheduled",
        notes: "Regular check-up appointment"
      }) do
        {:ok, appointment} ->
          IO.puts("✅ Appointment created: #{child.name} with #{provider.name} on #{date}")
        {:error, changeset} ->
          IO.puts("⚠️  Appointment creation failed: #{inspect(changeset.errors)}")
      end
    else
      IO.puts("ℹ️  Appointment already exists for #{child.name} with #{provider.name} on #{date}")
    end
  end)
else
  IO.puts("⚠️  Cannot create appointments - no providers or children available")
end

# Initialize vaccine schedules
IO.puts("Initializing vaccine schedules...")
try do
  App.HealthRecords.initialize_standard_vaccine_schedules()
  IO.puts("✅ Vaccine schedules initialized")
rescue
  e ->
    IO.puts("⚠️  Vaccine schedule initialization failed: #{inspect(e)}")
end

# Generate immunization schedules for children
IO.puts("Generating immunization schedules for children...")
Enum.each(all_children, fn child ->
  try do
    App.HealthRecords.generate_immunization_schedule(child.id)
    IO.puts("✅ Immunization schedule generated for #{child.name}")
  rescue
    e ->
      IO.puts("⚠️  Immunization schedule generation failed for #{child.name}: #{inspect(e)}")
  end
end)

# Create some sample growth records
IO.puts("Creating sample growth records...")
Enum.each(all_children, fn child ->
  age_months = App.Accounts.Child.age_in_months(child)

  # Create 2-3 growth records at different dates
  growth_dates = [
                   Date.add(Date.utc_today(), -90),  # 3 months ago
                   Date.add(Date.utc_today(), -30),  # 1 month ago
                   Date.utc_today()                  # Today
                 ]
                 |> Enum.filter(&(Date.compare(&1, child.date_of_birth) == :gt))  # Only dates after birth

  Enum.with_index(growth_dates)
  |> Enum.each(fn {date, index} ->
    # Generate age-appropriate growth measurements
    base_weight = case age_months do
      months when months < 6 -> Decimal.new("#{3.5 + months * 0.7}")
      months when months < 12 -> Decimal.new("#{7.0 + (months - 6) * 0.4}")
      months when months < 24 -> Decimal.new("#{9.5 + (months - 12) * 0.2}")
      _ -> Decimal.new("#{12.0 + (age_months - 24) * 0.15}")
    end

    base_height = case age_months do
      months when months < 6 -> Decimal.new("#{50 + months * 3}")
      months when months < 12 -> Decimal.new("#{68 + (months - 6) * 1.5}")
      months when months < 24 -> Decimal.new("#{77 + (months - 12) * 1}")
      _ -> Decimal.new("#{89 + (age_months - 24) * 0.8}")
    end

    # Add some variation for growth progression
    weight_variation = Decimal.new("#{index * 0.3}")
    height_variation = Decimal.new("#{index * 1.2}")

    weight = Decimal.add(base_weight, weight_variation)
    height = Decimal.add(base_height, height_variation)
    head_circumference = Decimal.new("#{35 + age_months * 0.3}")

    case App.HealthRecords.create_growth_record(%{
      child_id: child.id,
      weight: weight,
      height: height,
      head_circumference: head_circumference,
      measurement_date: date,
      notes: "Routine measurement"
    }) do
      {:ok, _growth_record} ->
        if index == length(growth_dates) - 1 do
          IO.puts("✅ Growth records created for #{child.name}")
        end
      {:error, changeset} ->
        IO.puts("⚠️  Growth record creation failed for #{child.name}: #{inspect(changeset.errors)}")
    end
  end)
end)

IO.puts("\n🎉 Database seeding completed!")
IO.puts("\n📊 Summary:")
IO.puts("- Admin users: 1")
IO.puts("- Provider users: #{length(providers)}")
IO.puts("- Parent users: #{length(parents)}")
IO.puts("- Children: #{length(all_children)}")
IO.puts("- Vaccine schedules: Initialized")
IO.puts("\n🔐 Login credentials:")
IO.puts("Admin: admin@example.com / adminpassword123")
IO.puts("Provider: sarah.johnson@example.com / providerpass123")
IO.puts("Parent: john.doe@example.com / parentpass123")
IO.puts("\n💡 You can now start the server with: mix phx.server")