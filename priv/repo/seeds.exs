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
# priv/repo/seeds.exs
alias App.Repo
alias App.Accounts
alias App.Scheduling
alias App.Notifications

# Create admin user
{:ok, _admin} =
  Accounts.register_user(%{
    "name" => "Admin User",
    "email" => "admin@example.com",
    "phone" => "+1234567890",
    "password" => "adminpassword123",
    "password_confirmation" => "adminpassword123",
    "role" => "admin"
  })

# Create provider users and their provider profiles
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
      "specialization" => "pediatrician"
    }
  },
  %{
    user: %{
      "name" => "Dr. Michael Chen",
      "email" => "michael.chen@example.com",
      "phone" => "+1234567892",
      "password" => "providerpass123",
      "password_confirmation" => "providerpass123",
      "role" => "provider"
    },
    provider: %{
      "name" => "Dr. Michael Chen",
      "specialization" => "pediatrician"
    }
  },
  %{
    user: %{
      "name" => "Nurse Jane Smith",
      "email" => "jane.smith@example.com",
      "phone" => "+1234567893",
      "password" => "providerpass123",
      "password_confirmation" => "providerpass123",
      "role" => "provider"
    },
    provider: %{
      "name" => "Nurse Jane Smith",
      "specialization" => "nurse"
    }
  }
]

providers =
  Enum.map(providers_data, fn data ->
    {:ok, user} = Accounts.register_user(data.user)
    {:ok, provider} = Scheduling.create_provider(Map.put(data.provider, "user_id", user.id))
    provider
  end)

# Create schedules for providers
Enum.each(providers, fn provider ->
  # Monday through Friday, 9 AM to 5 PM
  Enum.each(1..5, fn day ->
    Scheduling.create_schedule(provider, %{
      "day_of_week" => day,
      "start_time" => ~T[09:00:00],
      "end_time" => ~T[17:00:00]
    })
  end)
end)

# Create sample parent user
{:ok, parent} =
  Accounts.register_user(%{
    name: "John Doe",
    email: "john.doe@example.com",
    phone: "+1234567894",
    password: "parentpass123",
    password_confirmation: "parentpass123",
    role: "parent"
  })

# Create children for the parent
children_data = [
  %{
    "name" => "Emma Hara",
    "date_of_birth" => ~D[2021-06-15]
  },
  %{
    "name" => "Oliver Doe",
    "date_of_birth" => ~D[2023-02-10]
  }
]

children =
  Enum.map(children_data, fn child_data ->
    {:ok, child} = Accounts.create_child(parent, child_data)
    child
  end)

# Create sample appointments
today = Date.utc_today()
next_week = Date.add(today, 7)

Enum.each(children, fn child ->
  provider = Enum.random(providers)

  Scheduling.create_appointment(%{
    child_id: child.id,
    provider_id: provider.id,
    scheduled_date: next_week,
    scheduled_time: ~T[10:00:00],
    status: "scheduled",
    notes: "Regular check-up"
  })
end)

App.HealthRecords.initialize_standard_vaccine_schedules()
