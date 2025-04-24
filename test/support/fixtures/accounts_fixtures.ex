defmodule App.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `App.Accounts` context.
  """

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> App.Accounts.register_user()

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  @doc """
  Generate a unique child medical_record_number.
  """
  def unique_child_medical_record_number, do: "some medical_record_number#{System.unique_integer([:positive])}"

  @doc """
  Generate a child.
  """
  def child_fixture(attrs \\ %{}) do
    {:ok, child} =
      attrs
      |> Enum.into(%{
        date_of_birth: ~D[2025-04-21],
        medical_record_number: unique_child_medical_record_number(),
        name: "some name"
      })
      |> App.Accounts.create_child()

    child
  end
end
