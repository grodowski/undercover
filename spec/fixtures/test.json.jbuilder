json.title @title

if @user
  json.user do
    json.name @user.name
    json.email @user.email
  end
else
  json.user nil
end

json.timestamp Time.now.iso8601
